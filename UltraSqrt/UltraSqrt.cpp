// UltraSqrt.cpp

// includes
#include <stdlib.h>
#include <stdio.h>
#include <malloc.h>
#include <Windows.h>

// typedefs
typedef unsigned long ulong;
typedef unsigned long long ulonlong;
typedef unsigned long udeclong;

// output limit (=max number of fraction decadic digits)
#define OUTPUT_LIMIT 20000000

// printf and scanf formats
#define uL      "%lu"
#define uLL     "%llu"
#define u8LL    "%8llu"
#define u016LLX "0x%016llX"

// time output
#define fTime "%5u.%02u second(s)"
#define pTime(time) \
        time / 1000, time / 10 % 100

// decimal digit GROUPs, binary bits of WORDs
#define DECDIG  27
#define BYTES   sizeof(ulonlong)
#define BINBITS 8*BYTES
#define XWORD   "0hf_D_T_Q"[BYTES]

// 0-th 1-st 2-nd 3-rd
#define TH(num) \
        "_0th\0_1st\0_2nd\0_3rd"+(5*(num%10<4?num%10:0)+2)

// lg2(10) <= LG10_NUM/LG10_DEN
#define LG10_NUM 28738
#define LG10_DEN  8651

// decimal output
#define UDECLDIG 9
#define iDec "%lu."
#define fDec "%0*lu%0*lu%0*lu"
#define pDec(hi, mi, lo) \
        DECDIG-2*UDECLDIG, hi, UDECLDIG, mi, UDECLDIG, lo

// line wrapping of the decimal output
#define OUTPUT_WRAP 100

// percentage printing "  0.00 %" - "100.00 %"
#define fPerc "%3llu.%02llu%%"
#define pPerc(part, total) \
        total ? 100*part/total : 0, total ? 10000*part/total%100 : 0

// Data used in processing

// aux variables
ulonlong num, shift;
ulonlong lead, next;

// pointers and iterators
ulonlong *bas_beg, *bas_end;
ulonlong *res_beg, *res_mid, *res_end;

// binary error(s)
ulonlong hi_err, lo_err;

// decimal output
udeclong hi_dec, mi_dec, lo_dec;
ulonlong dec_size, dec_mul, dec_split;

// assembler functions
int sqrt_init_qword();
int sqrt_guess_next();
int sqrt_check_next();
int sqrt_calc_error();
int sqrt_subtr_next();
int sqrt_b2dec_init();
int sqrt_b2dec_next();

int main(int argc, char* argv[])
{
    // arguments
    const ulong MAX_DIGITS = OUTPUT_LIMIT;
    ulong arg_num, arg_len;

    // scan and check cmd line arguments
    bool isOk = true;
    if(isOk) isOk = (argc == 3);
    if(isOk) isOk = (sscanf_s(argv[1], uL, &arg_num) == 1 && arg_num != 0);
    if(isOk) isOk = (sscanf_s(argv[2], uL, &arg_len) == 1 && arg_len <= MAX_DIGITS);
    if(isOk) {
        // print input 'arg_num' value
        printf("sqrt(" uL ")\n\n", arg_num);
    } else {
        printf("Use: %s <number> <length>, where <length> <= " uL "\n\n", argv[0], MAX_DIGITS);
        return 1;
    }

    // iterators
    ulonlong i, j, k;

    // How many WORDs of BINBITS each is needed to carry binary data
    // corresponding to required groups of DECDIG decimal digits
    // WORDS/DECGROUPS must be slightly more than DECDIG*lg2(10)/BINBITS
    const ulonlong WORDS = DECDIG * LG10_NUM, DECGROUPS = LG10_DEN * BINBITS;
    const ulonlong dec_len = (ulonlong) (arg_len + DECDIG-1) / DECDIG;
    const ulonlong len = (WORDS * dec_len + DECGROUPS-1) / DECGROUPS;
    printf("* dec  fract part : " u8LL " figure(s)\n", DECDIG * dec_len);
    printf("* bin  fract size : " u8LL " %c-WORD(s)\n", len, XWORD);
    printf("\n");

    // start time
    DWORD start_time = GetTickCount();

    // memory allocation for binary calculations
    ulonlong* binar = (ulonlong*) malloc((len + 4) * BYTES);
    memset(binar, 0, (len + 4) * BYTES);

    // initiation of 'base' and 'rest'
    ulonlong* base = bas_beg = bas_end = binar + (2);
    ulonlong* rest = res_beg = res_end = binar;

    // calculate first QWORD of partial result
    num = (ulonlong) arg_num;
    sqrt_init_qword();

    // adapt statistics
    const ulonlong MAX_ADAPT = 2;
    ulonlong adapt_stat[MAX_ADAPT + 1];
    for (i = 0; i <= MAX_ADAPT; ++i) adapt_stat[i] = 0;

    // cycle for next QWORD of the result
    bool base_error = false;
    hi_err = lo_err = 0;
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

        // calc error
        if (j < 2*i) {
            sqrt_calc_error();
        }

        // perform subtraction if 'next' > 0
        if (next != 0) {
            sqrt_subtr_next();
        }

        // check if *bas_beg is zero
        base_error |= (*bas_beg != 0);
    }

    // remember lead, next and shift statistics
    ulonlong lead_stat = rest[0];
    ulonlong next_stat = rest[1];
    ulonlong shift_stat = shift;

    // base remainder
    ulonlong base_rem_pos = base[len] ? len : 0;
    ulonlong base_rem_val = base[len];

    // binary calculation time
    DWORD binar_time = GetTickCount();

    // allocate memory for decadic output
    udeclong* deci = (udeclong*) malloc((3 * dec_len + 1) * sizeof(udeclong));

    // binary to dec preparation
    dec_size = DECDIG;
    dec_mul = 1; for (i = 0; i < DECDIG; ++i) dec_mul *= 5;
    dec_split = 1; for (i = 0; i < UDECLDIG; ++i) dec_split *= 10;

    // binary to decimal "init"
    sqrt_b2dec_init();
    deci[0] = hi_dec;

    // binary to decimal "next" digits
    ulonlong b2dec_str = res_end - res_beg;
    j = len + 1;
    k = 0;
    for (i = 0; i < dec_len; ++i) {
        // restriction of the "remaining" binary result to only relevalt QWORDs
        // j = len + 1 - WORDS * i / DECGROUPS;
        if (k >= DECGROUPS) { k -= DECGROUPS; --j; }
        res_mid = res_beg + (j);
        k += WORDS; k-= DECGROUPS; --j;
        // multiplication and shift
        sqrt_b2dec_next();
        // storing of the decimal output
        deci[3*i+1] = hi_dec;
        deci[3*i+2] = mi_dec;
        deci[3*i+3] = lo_dec;
    }
    ulonlong b2dec_end = (res_end >= res_beg ? res_end - res_beg : 0);

    // release memory with binary result
    free(binar);

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
    printf("* binary lead word: " u016LLX "\n", lead_stat);
    printf("* binary next word: " u016LLX "\n", next_stat);
    printf("* binary res shift: <<    " uLL " bits\n", shift_stat);
    printf("\n");
    for (i = 0; i <= MAX_ADAPT; ++i) {
        ulonlong adapt = adapt_stat[i];
        printf("* next adapted +" uLL " : " u8LL " x " fPerc "\n", i, adapt, pPerc(adapt, len));
    }
    printf("* bin calc cycles : " u8LL " # iter(s)\n", len);
    printf("\n");
    if (base_error) {
        printf("* binary remainder: !!! ERROR !!!\n");
    } else {
        printf("* binary rem t-pos: " u8LL " %s %c-WORD\n", base_rem_pos, TH(base_rem_pos), XWORD);
        bool rem_too_low = (hi_err > 0 && hi_err >= base_rem_val);
        printf("* binary rem t-val: " u016LLX "%s\n", base_rem_val, (rem_too_low ? " << !!!" : ""));
        printf("* binary err t-val: " u016LLX "%s\n", hi_err,       (rem_too_low ? " >> !!!" : ""));
    }
    printf("\n");
    printf("* bi2dec start sz : " u8LL " %c-WORD(s)\n", b2dec_str, XWORD);
    printf("* bi2dec final sz : " u8LL " %c-WORD(s)\n", b2dec_end, XWORD);
    printf("* dec calc cycles : " u8LL " # iter(s)\n", dec_len);
    printf("\n");

    // print the result
    printf(iDec "\n", deci[0]);
    const ulonlong WRAP = OUTPUT_WRAP;
    char line[WRAP + DECDIG];
    ulonlong pos = 0;
    for (i = 0; i < dec_len; ++i) {
        sprintf_s(line + (pos), DECDIG + 1, fDec, pDec(deci[3*i+1], deci[3*i+2], deci[3*i+3]));
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