#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include "locatedb.h"

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>
#include <fnmatch.h>

#define NDEBUG
#include <assert.h>

#ifdef STDC_HEADERS
#include <stdlib.h>
#else
char *getenv ();
#endif

#ifdef STDC_HEADERS
#include <errno.h>
#include <stdlib.h>
#else
extern int errno;
#endif

#define MIN_CHUNK 64

#ifndef call_sv
#   define call_sv perl_call_sv
#endif

typedef enum {false, true} boolean;

static char * last_literal_end (char *name) {
    static char *globfree = NULL;	/* A copy of the subpattern in NAME.  */
    static size_t gfalloc = 0;	    /* Bytes allocated for `globfree'.  */
    register char *subp;		    /* Return value.  */
    register char *p;		        /* Search location in NAME.  */

    /* Find the end of the subpattern.
     Skip trailing metacharacters and [] ranges. */
    for (p = name + strlen (name) - 1; 
         p >= name && strchr ("*?]", *p) != NULL;
         p--) {
        
        if (*p == ']')
            while (p >= name && *p != '[')
                p--;
    }
    
    if (p < name)
        p = name;

    if (p - name + 3 > gfalloc) {
        gfalloc = p - name + 3 + 64; /* Room to grow.  */
        globfree = saferealloc (globfree, gfalloc);
    }
    
    subp = globfree;
    *subp++ = '\0';

    /* If the pattern has only metacharacters, make every path match the
     subpattern, so it gets checked the slow way.  */
    if (p == name && strchr ("?*[]", *p) != NULL)
        *subp++ = '/';
    else {
        char *endmark;
        /* Find the start of the metacharacter-free subpattern.  */
        for (endmark = p; p >= name && strchr ("]*?", *p) == NULL; p--)
            ;
        /* Copy the subpattern into globfree.  */
        for (++p; p <= endmark; )
            *subp++ = *p++;
    }
    
    *subp-- = '\0';		/* Null terminate, though it's not needed.  */

    return subp;
}

int getstr (char **lineptr, size_t *n, FILE *stream, 
            char terminator, int offset) {
    int nchars_avail;		/* Allocated but unused chars in *LINEPTR.  */
    char *read_pos;		/* Where we're reading into *LINEPTR. */
    int ret;

    if (!lineptr || !n || !stream)
        return -1;

    if (!*lineptr) {
        *n = MIN_CHUNK;
        *lineptr = malloc (*n);
        if (!*lineptr)
            return -1;
    }

    nchars_avail = *n - offset;
    read_pos = *lineptr + offset;

    for (;;) {
        register int c = getc (stream);

        /* We always want at least one char left in the buffer, since we
           always (unless we get an error while reading the first char)
           NULL-terminate the line buffer.  */

        assert(*n - nchars_avail == read_pos - *lineptr);
        if (nchars_avail < 1) {
            if (*n > MIN_CHUNK)
                *n *= 2;
            else
                *n += MIN_CHUNK;

            nchars_avail = *n + *lineptr - read_pos;
            *lineptr = realloc (*lineptr, *n);
            if (!*lineptr)
                return -1;
            read_pos = *n - nchars_avail + *lineptr;
            assert(*n - nchars_avail == read_pos - *lineptr);
        }

        if (c == EOF || ferror (stream)) {
            /* Return partial line, if any.  */
            if (read_pos == *lineptr)
                return -1;
            else
                break;
        }

        *read_pos++ = c;
        nchars_avail--;

        if (c == terminator)
            /* Return the line.  */
            break;
    }

    /* Done - NUL terminate and return the number of chars read.  */
    *read_pos = '\0';

    ret = read_pos - (*lineptr + offset);
    return ret;
}

static int get_short (FILE *fp) {
    char x[2];
    fread((void*)&x, 2, 1, fp);
    return ((x[0]<<8)|(x[1]&0xff));
}

void call_coderef (SV *coderef, char *path) {
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpvn(path, strlen(path))));
    PUTBACK;

    (void) call_sv(coderef, G_DISCARD);
    
    FREETMPS;
    LEAVE;
}

#define WARN fprintf(stderr, "%i\n", __LINE__);

MODULE = File::Locate		PACKAGE = File::Locate		

INCLUDE: const-xs.inc

void
locate (pathpart, ...) 
        char *pathpart;
    PROTOTYPE: DISABLE
    PREINIT:
        char *dbfile = NULL;
        SV   *coderef = NULL;
        FILE *fp;           /* The pathname database.  */
        int c;              /* An input byte.  */
        int nread;          /* Number of bytes read from an entry.  */
        boolean globflag;   /* true if PATHPART contains globbing 
                               metacharacters.  */
        char *patend;       /* The end of the last glob-free subpattern 
                               in PATHPART.  */
        char *path;         /* The current input database entry.  */
        size_t pathsize;    /* Amount allocated for it.  */
        int count = 0;      /* The length of the prefix shared with 
                               the previous database entry.  */
        char *cutoff;       /* Where in `path' to stop the backward search for
                               the last character in the subpattern.  Set
                               according to `count'.  */
        boolean prev_fast_match = false;    /* true if we found a fast match
                                               (of patend) on the previous
                                               path.  */
        int printed = 0;                    /* The return value.  */
        boolean old_format = false;         /* true if reading a bigram-encoded
                                               database.  */
        char bigram1[128], bigram2[128];    /* For the old database format, the
                                               first and second characters of
                                               the most common bigrams.  */
        STRLEN sTrLeN;
    PPCODE:
        while (--items) {
            if (SvROK(ST(items)) && SvTYPE((SV*)SvRV(ST(items))) == SVt_PVCV) {
                coderef = newSVsv(ST(items));
            }
            else 
                dbfile = SvPV(ST(items), sTrLeN);
        }

        if (!dbfile) {
            dbfile = getenv("LOCATE_PATH");
            if (!dbfile)
                dbfile = strdup(LOCATE_DB);
        }

        if ((fp = fopen (dbfile, "r")) == NULL) 
            XSRETURN_UNDEF;

        pathsize = 1026;		/* Increased as necessary by getstr.  */
        path = safemalloc (pathsize);

        nread = fread (path, 1, sizeof (LOCATEDB_MAGIC), fp);
        if (nread != sizeof (LOCATEDB_MAGIC) || 
            memcmp (path, LOCATEDB_MAGIC, sizeof (LOCATEDB_MAGIC))) {
            int i;
            /* Read the list of the most common bigrams in the database.  */
            fseek (fp, 0, 0);
            for (i = 0; i < 128; i++) {
                bigram1[i] = getc (fp);
                bigram2[i] = getc (fp);
            }
            old_format = true;
        }

        globflag =  strchr (pathpart, '*') || 
                    strchr (pathpart, '?') || 
                    strchr (pathpart, '[');

        patend = last_literal_end (pathpart);

        c = getc (fp);
        while (c != EOF) {
            register char *s;		/* Scan the path we read in.  */

            if (old_format) {
                /* Get the offset in the path where this path info starts.  */
                if (c == LOCATEDB_OLD_ESCAPE)
                    count += getw (fp) - LOCATEDB_OLD_OFFSET;
                else
                    count += c - LOCATEDB_OLD_OFFSET;

                /* Overlay the old path with the remainder of the new.  */
                for (s = path + count; (c = getc (fp)) > LOCATEDB_OLD_ESCAPE;)
                    if (c < 0200)
                        *s++ = c;		/* An ordinary character.  */
                    else {
                        /* Bigram markers have the high bit set. */
                        c &= 0177;
                        *s++ = bigram1[c];
                        *s++ = bigram2[c];
                    }
                *s-- = '\0';
            }
            else {
                if (c == LOCATEDB_ESCAPE)
                    count += get_short (fp);
                else if (c > 127)
                    count += c - 256;
                else
                    count += c;

                /* Overlay the old path with the remainder of the new.  */
                nread = getstr (&path, &pathsize, fp, '\0', count);
                if (nread < 0)
                    break;
                c = getc (fp);
                /* Move to the last char in path. */
                s = path + count + nread - 2; 
                assert (s[0] != '\0');
                assert (s[1] == '\0'); /* Our terminator.  */
                assert (s[2] == '\0'); /* Added by getstr.  */
            }

            /* If the previous path matched, scan the whole path for the last
               char in the subpattern.  If not, the shared prefix doesn't match
               the pattern, so don't scan it for the last char.  */
            cutoff = prev_fast_match ? path : path + count;

            /* Search backward starting at the end of the path we just read in,
               for the character at the end of the last glob-free subpattern in
               PATHPART.  */
            for (prev_fast_match = false; s >= cutoff; s--) {
                /* Fast first char check. */
                if (*s == *patend) {
                    char *s2;		/* Scan the path we read in. */
                    register char *p2;	/* Scan `patend'.  */

                    for (s2 = s - 1, p2 = patend - 1; 
                         *p2 != '\0' && *s2 == *p2;
                         s2--, p2--)
                        ;
                    if (*p2 == '\0') {
                        /* Success on the fast match.  Compare the whole pattern
                           if it contains globbing characters.  */
                        prev_fast_match = true;
                        if (globflag == false || 
                            fnmatch (pathpart, path, 0) == 0) {
                          if (coderef) {
                            call_coderef(coderef, path);
                          }
                          else if (GIMME_V == G_ARRAY) 
                            XPUSHs(sv_2mortal(newSVpvn(path, strlen(path))));
                          else {
                            safefree(path);
                            XSRETURN_YES;
                            }
                          ++printed;
                          }
                          break;
                    }
                }
            }
        }

        if (ferror (fp)) 
            XSRETURN_UNDEF;
            
        if (fclose (fp) == EOF) 
            XSRETURN_UNDEF;
        
        safefree(path);

        if(GIMME_V == G_ARRAY)
            XSRETURN(printed);
        else 
            XSRETURN_NO;

