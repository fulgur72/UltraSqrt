// UltraSqrt.cpp
#include <stdlib.h>
#include <stdio.h>
#include <malloc.h>

#include <Windows.h>

typedef unsigned long ulong;
typedef unsigned long long ulonlong;

// Data used in processing

// aux variables
ulonlong num, shift;
ulonlong lead, next;

// pointers and iterators
ulonlong *bas_beg, *bas_end;
ulonlong *res_beg, *res_mid, *res_end;

// decimal output
ulonlong hi_dec, lo_dec;

// adapt statistics
const ulonlong MAX_ADAPT = 2;
ulonlong adapt_stat[MAX_ADAPT+1];

// assembler functions
int sqrt_init_qword();
int sqrt_next_guess();
int sqrt_check_next();
int sqrt_subtr_next();
int sqrt_bin_to_dec();

int main(int argc, char* argv[])
{
    // scan and checks parameters
    const ulong MAX_LEN = 10000000;
    ulong arg_num, arg_len;
    bool isOk = true;
    if(isOk) isOk = (argc == 3);
    if(isOk) isOk = (sscanf_s(argv[1],"%lu",&arg_num) == 1 && arg_num != 0);
    if(isOk) isOk = (sscanf_s(argv[2],"%lu",&arg_len) == 1 && arg_len <= MAX_LEN);

    if(! isOk) {
        printf("Incorrect arguments: %s <number> <length>, where length is decimal leq %lu\n",
          argv[0], MAX_LEN);
        return 1;
    }

    // print input 'arg_num' value
    printf("sqrt(%lu)\n", arg_num);

    // How many QWORDs of 64 bit each is needed to carry binary data
    // corresponding to required groups of DECDIG decimal digits
    // QWORDS/DECGROUPS must be slightly more than DECDIG*ln(10)/64*ln(2)
    const ulonlong DECDIG = 27;
    const ulonlong QWORDS = 125489, DECGROUPS = 89543;
    ulonlong dec_len = ((ulonlong)arg_len + (DECDIG-1)) / DECDIG;
    ulonlong len = (QWORDS * dec_len + (DECGROUPS-1)) / DECGROUPS;
    printf("decimal figures: %8llu\n", DECDIG * dec_len);
    printf("binary bytes:    %8llu\n", sizeof(ulonlong) * len);

    // iterators
    ulonlong i, j;

    // reset adapt statistics
    for (i = 0; i <= MAX_ADAPT; ++i) adapt_stat[i] = 0;

    // start time
    DWORD start_time = GetTickCount();

    // memory allocation and initial cleaning
    ulonlong* rest = (ulonlong*) malloc((len + 4) * sizeof(ulonlong));
    rest[0] = rest[1] = 0;
    ulonlong* base = rest + 2;
    for (i = 0; i <= len+1; ++i) base[i] = 0;

    // calculate first QWORD of partial result
    num = (ulonlong) arg_num;
    bas_beg = base;
    res_beg = rest;
    sqrt_init_qword();

    // cycle for next QWORD of the result
    for(i = 1; i <= len; ++i) {

        // pointers to the beginning and end of the base and rest
        j = 2*i <= len ? 2*i : len+1;
        bas_beg = base + (i-1);
        bas_end = base + (j);
        res_beg = rest;
        res_mid = rest + (j-i);
        res_end = rest + (i);

        // compute next DWORD
        lead = *res_beg + 1;
        if (lead == 0) {
            next = *bas_beg;
        } else {
            sqrt_next_guess();
        }

        // check next QWORD and try to adapt it
        sqrt_check_next();

        // set next QWORD to the end of partial result
        *res_end = next;

        // perform main action if "next" > 0
        if (next != 0) {
            sqrt_subtr_next();
        }
    }

    // remember lead, next and shift for statistics
    ulonlong lead_stat = rest[0];
    ulonlong next_stat = rest[1];
    ulonlong shift_stat = shift;

    // move the result right by half of the bits
    // which the base was shifted left in the beginning
    // res_beg = rest;
    // res_end = rest + (len + 1);
    // sqrt_shift_rest();

    // binar time
    DWORD binar_time = GetTickCount();

    // allocate memory for decadit output
    ulonlong* deci = (ulonlong*) malloc((2 * dec_len + 1) * sizeof(ulonlong));

    // translation of binary data into decadic - initial "whole" part
    deci[0] = rest[0] >> shift;

    // translation of binary data into decadic - further "fraction" digits
    res_beg = rest;
    res_end = rest + (len);
    ulonlong b2dec_str = res_end - res_beg + 1;
    for(i = 0; i < dec_len; ++i) {
        // multiplication and shift
        res_mid = res_beg + len + 1 - (QWORDS * i) / DECGROUPS;
        sqrt_bin_to_dec();
        // storing of the decimal output
        deci[2*i+1] = hi_dec;
        deci[2*i+2] = lo_dec;
    }
    ulonlong b2dec_end = (res_end >= res_beg ? res_end - res_beg + 1 : 0);

    // release memory with binary result
    free(rest);

    // b2dec time
    DWORD b2dec_time = GetTickCount();

    // print evaluation time(s)
    DWORD time;
    time = binar_time - start_time;
    printf("binar_calc time: %5u.%02u\n", time/1000, time%1000/10);
    time = b2dec_time - binar_time;
    printf("binary2dec time: %5u.%02u\n", time/1000, time%1000/10);
    time = b2dec_time - start_time;
    printf("total_calc time: %5u.%02u\n", time/1000, time%1000/10);
    printf("\n");

    // print the result
    printf("%llu.\n", deci[0]);
    const ulonlong OUTPUT_SIZE = 100;
    char line[OUTPUT_SIZE + DECDIG];
    ulonlong pos = 0;
    for(i = 0; i < dec_len; ++i) {
        sprintf_s(line + pos, DECDIG + 1, "%015llu%012llu", deci[2*i+1], deci[2*i+2]);
        pos += DECDIG;
        if (pos >= OUTPUT_SIZE) {
            pos -= OUTPUT_SIZE;
            char oc = line[OUTPUT_SIZE]; line[OUTPUT_SIZE] = 0;
            printf("%s\n", line);
            line[0] = oc; for (j = 1; j <= pos; ++j) line[j] = line[OUTPUT_SIZE+j];
        }
    }
    if (pos > 0) {
        printf("%s\n", line);
    }

    // release memory for decadic output
    free(deci);

    // print statistics
    printf("\n");
    printf("* binary lead: 0x%016llX\n", lead_stat);
    printf("* binary next: 0x%016llX\n", next_stat);
    printf("* binar shift: << %2llu bits\n", shift_stat);
    for (i = 0; i <= MAX_ADAPT; ++i) {
        printf("*  bin adapt %llux: %8llu\n", i, adapt_stat[i]);
    }
    printf("* binary cycles: %8llu\n", len);
    printf("* bi2dec start#: %8llu\n", b2dec_str);
    printf("* bi2dec final#: %8llu\n", b2dec_end);
    printf("* bi2dec cycles: %8llu\n", dec_len);

    return 0;
}