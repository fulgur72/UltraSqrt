// UltraSqrt.cpp
#include <stdlib.h>
#include <stdio.h>
#include <malloc.h>

#include <Windows.h>

typedef unsigned long ulong;
typedef unsigned long long ulonlong;

#define uL  "%lu"
#define uLL "%llu"
#define u8LL "%8llu"
#define u016LLX "0x%016llX"

#define fTime "%5u.%02u"
#define pTime(time) time/1000, time%1000/10

#define OUTPUT_WRAP 100
#define fDec "%0*llu%0*llu"

#define fPerc "%3llu.%02llu %%"
#define pPerc(part,total) 100*part/total, 10000*part/total%100

// Data used in processing

// aux variables
ulonlong num, shift;
ulonlong lead, next;

// pointers and iterators
ulonlong *bas_beg, *bas_end;
ulonlong *res_beg, *res_mid, *res_end;

// decimal output
ulonlong hi_dec, lo_dec;
ulonlong dec_size, dec_mul, dec_split;

// assembler functions
int sqrt_init_qword();
int sqrt_guess_next();
int sqrt_check_next();
int sqrt_subtr_next();
int sqrt_b2dec_init();
int sqrt_b2dec_next();

int main(int argc, char* argv[])
{
    // arguments
    const ulong MAX_LEN = 10000000;
    ulong arg_num, arg_len;

    // scan and check cmd line arguments
    bool isOk = true;
    if(isOk) isOk = (argc == 3);
    if(isOk) isOk = (sscanf_s(argv[1], uL, &arg_num) == 1 && arg_num != 0);
    if(isOk) isOk = (sscanf_s(argv[2], uL, &arg_len) == 1 && arg_len <= MAX_LEN);
    if(isOk) {
        // print input 'arg_num' value
        printf("sqrt(" uL ")\n", arg_num);
    } else {
        printf("Use: %s <number> <length>, where <length> <= " uL "\n", argv[0], MAX_LEN);
        return 1;
    }

    // c++ iterators
    ulonlong i, j;

    // How many QWORDs of 64 bit each is needed to carry binary data
    // corresponding to required groups of DECDIG decimal digits
    // QWORDS/DECGROUPS must be slightly more than DECDIG*ln(10)/64*ln(2)
    const ulonlong DECDIG = 27;
    const ulonlong QWORDS = 125489, DECGROUPS = 89543;
    ulonlong dec_len = ((ulonlong)arg_len + (DECDIG-1)) / DECDIG;
    ulonlong len = (QWORDS * dec_len + (DECGROUPS-1)) / DECGROUPS;
    printf("* decadic  figures: " u8LL "\n", DECDIG * dec_len);
    printf("* binary data size: " u8LL "\n", sizeof(ulonlong) * len);

    // start time
    DWORD start_time = GetTickCount();

    // memory allocation and initiation of 'rest'
    ulonlong* rest = (ulonlong*) malloc((len + 4) * sizeof(ulonlong));
    rest[0] = rest[1] = 0;
    res_beg = res_end = rest;

    // initiation of 'base' (sharing memory with 'rest')
    ulonlong* base = rest + (2);
    for (i = 0; i <= len+1; ++i) base[i] = 0;
    bas_beg = bas_end = base;

    // calculate first QWORD of partial result
    num = (ulonlong) arg_num;
    sqrt_init_qword();

    // adapt statistics
    const ulonlong MAX_ADAPT = 2;
    ulonlong adapt_stat[MAX_ADAPT + 1];
    for (i = 0; i <= MAX_ADAPT; ++i) adapt_stat[i] = 0;

    // cycle for next QWORD of the result
    for (i = 1; i <= len; ++i) {

        // update 'base' and 'rest' pointers
        j = (2*i <= len ? 2*i : len+1);
        bas_beg = base + (i-1);
        bas_end = base + (j);
        res_mid = rest + (j-i);
        res_end = rest + (i);

        // compute next QWORD
        lead = *res_beg + 1;
        if (lead == 0) {
            next = *bas_beg;
        } else {
            sqrt_guess_next();
        }

        // check next QWORD and try to adapt it
        ulonlong next_guess = next;
        sqrt_check_next();
        ++ adapt_stat[next-next_guess];

        // set next QWORD to the end of partial result
        *res_end = next;

        // perform subtraction if 'next' > 0
        if (next != 0) {
            sqrt_subtr_next();
        }
    }

    // remember lead, next and shift statistics
    ulonlong lead_stat = rest[0];
    ulonlong next_stat = rest[1];
    ulonlong shift_stat = shift;

    // binary calculation time
    DWORD binar_time = GetTickCount();

    // allocate memory for decadic output
    ulonlong* deci = (ulonlong*) malloc((2 * dec_len + 1) * sizeof(ulonlong));

    // binary to dec preparation
    dec_size = DECDIG;
    dec_mul = 1; for (i = 0; i < DECDIG; ++i) dec_mul *= 5;
    dec_split = 1; for (i = 0; i < DECDIG/2; ++i) dec_split *= 10;

    // binary to decimal "init"
    sqrt_b2dec_init();
    deci[0] = hi_dec;

    // binary to decimal "next" digits
    ulonlong b2dec_str = res_end - res_beg + 1;
    for (i = 0; i < dec_len; ++i) {
        // restriction of the "remaining" binary result to only relevalt QWORDs
        res_mid = res_beg + len + 1 - (QWORDS * i) / DECGROUPS;
        // multiplication and shift
        sqrt_b2dec_next();
        // storing of the decimal output
        deci[2*i+1] = hi_dec;
        deci[2*i+2] = lo_dec;
    }
    ulonlong b2dec_end = (res_end >= res_beg ? res_end - res_beg + 1 : 0);

    // release memory with binary result
    free(rest);

    // b2dec calculation time
    DWORD b2dec_time = GetTickCount();

    // print calculation time(s)
    DWORD time;
    time = binar_time - start_time;
    printf("* binary calc time: " fTime "\n", pTime(time));
    time = b2dec_time - binar_time;
    printf("* bi2dec calc time: " fTime "\n", pTime(time));
    time = b2dec_time - start_time;
    printf("* total  calc time: " fTime "\n", pTime(time));
    printf("\n");

    // print statistics
    printf("* binary lead: " u016LLX "\n", lead_stat);
    printf("* binary next: " u016LLX "\n", next_stat);
    printf("* binary shift   <<  " uLL " bits\n", shift_stat);
    for (i = 0; i <= MAX_ADAPT; ++i) {
        ulonlong adapt = adapt_stat[i];
        printf("* + bin adapt  " uLL "x : " u8LL " ~ " fPerc "\n", i, adapt, pPerc(adapt, len));
    }
    printf("* bin calc cycles : " u8LL "\n", len);
    printf("* bi2dec start ## : " u8LL "\n", b2dec_str);
    printf("* bi2dec final ## : " u8LL "\n", b2dec_end);
    printf("* dec calc cycles : " u8LL "\n", dec_len);
    printf("\n");

    // print the result
    printf(uLL ".\n", deci[0]);
    const ulonlong WRAP = OUTPUT_WRAP;
    char line[WRAP + DECDIG];
    ulonlong pos = 0;
    int size1 = (int) ((DECDIG+1)/2), size2 = (int) (DECDIG/2);
    for (i = 0; i < dec_len; ++i) {
        sprintf_s(line + (pos), DECDIG + 1, fDec, size1, deci[2*i+1], size2, deci[2*i+2]);
        pos += DECDIG;
        if (pos >= WRAP) {
            pos -= WRAP;
            char oc = line[WRAP]; line[WRAP] = 0;
            printf("%s\n", line);
            line[0] = oc; for (j = 1; j <= pos; ++j) line[j] = line[WRAP+j];
        }
    }
    if (pos > 0) {
        printf("%s\n", line);
    }

    // release memory for decadic output
    free(deci);

    return 0;
}