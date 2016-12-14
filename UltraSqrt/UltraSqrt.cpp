// UltraSqrt.cpp
#include <stdlib.h>
#include <stdio.h>
#include <malloc.h>

#include <Windows.h>

typedef unsigned long long ulong;

// Data used in processing
// "volatile" members used/modified in asm parts

// square num
ulong num;
// decadic and binar sizes
ulong dec_len, len;

// pointers and iterators
ulong *base, *rest;
ulong *bas_beg, *bas_end;
ulong *res_beg, *res_mid, *res_end;

// lead and next
volatile ulong lead, next;

// shift and hi+lo decadic parts
volatile ulong shift;
volatile ulong hi_dec, lo_dec;

// adapt statistics
const ulong MAX_ADAPT = 2;
ulong adapt_stat[MAX_ADAPT+1];
volatile ulong adapt;

// lead & next statistics
ulong lead_stat, next_stat;

// assembler functions
int sqrt_init_qword();
int sqrt_next_guess();
int sqrt_check_next();
int sqrt_subtr_next();
int sqrt_shift_rest();
int sqrt_bin_to_dec();
int sqrt_split_deci();

int main(int argc, char* argv[])
{
    // scan and checks parameters
    const unsigned long MAX_LEN = 10000000uL;
    unsigned long arg_num, arg_len;
    bool isOk = true;
    if(isOk) isOk = (argc == 3);
    if(isOk) isOk = (sscanf_s(argv[1],"%lu",&arg_num) == 1 && arg_num != 0);
    if(isOk) isOk = (sscanf_s(argv[2],"%lu",&arg_len) == 1 && arg_len <= MAX_LEN);

    if(! isOk) {
        printf("Incorrect arguments: %s <number> <length>, where length is decimal leq %lu\n",
          argv[0], MAX_LEN);
        return 1;
    }

    // fill QWORD num
    num = (ulong) arg_num;
	printf("sqrt(%llu)\n", num);

    // 164,403 QWORDs (64 bit) is needed to carry binary data
    // corresponding to 126,695 groups of 25 decimal digits each
    // because 164403/126695 is (only) slightly more than 25*ln(10)/64*ln(2)
    dec_len = (arg_len + (25-1)) / 25;
    len = (164403 * dec_len + (164403-1)) / 126695;
    dec_len *= 2; // 25 digits in two QWORDs
    printf("decimal figures: %8llu\n", 25 * dec_len / 2);
    printf("binary bytes:    %8llu\n", 8 * len);

    // iterators
    ulong i, j;

    // start time
    DWORD start_time = GetTickCount();

    // memory allocation base = actual base for rooting; rest = partial result
    base = (ulong*) malloc((dec_len+2) * sizeof(ulong));
    rest = (ulong*) malloc((len+2)     * sizeof(ulong));
    for(i = 0; i <= len+1; ++i) base[i] = rest[i] = 0;

    // calculate first QWORD of partial result
    sqrt_init_qword();

    // reset adapt statistics
    for(i = 0; i <= MAX_ADAPT; ++i) adapt_stat[i] = 0;

    // cycle for next DWORD of the result
    for(i = 1; i <= len; ++i) {

        // pointers to the beginning and end of the base and rest
        j = 2*i <= len ? 2*i : len+1;
        bas_beg = base + (i-1);
        bas_end = base + (j);
        res_beg = rest;
        res_mid = rest + (j-i);
        res_end = rest + (i);

        // compute next DWORD
        lead = rest[0] + 1;
        if (lead == 0) {
            next = *bas_beg;
        } else {
            sqrt_next_guess();
        }

        // check next DWORD and try to adapt it
        sqrt_check_next();
        // update adapt sttatistics
        ++ adapt_stat[adapt];

        // set next DWORD to the end of partial result
        *res_end = next;

        // perform main action if "next" > 0
        if (next != 0) {
            sqrt_subtr_next();
        }
    }

    // remember lead and next
    lead_stat = rest[0];
    next_stat = rest[1];

    // update result
    res_beg = rest;
    res_end = rest + (len+1);

    // move the result right by half of the bits
    // which the base was shifted left in the beginning
    sqrt_shift_rest();

    // binar time
    DWORD binar_time = GetTickCount();

    // transcode into decadic
    base[0] = rest[0];
    rest[0] = 0;

    // reset iterators
    bas_beg = base;
    bas_end = base;
    res_beg = rest+(1);
    res_end = rest+(j = len+1);

    // reset shift
    shift = 0;

    // 25 figures by 25 figures
    for(i = 1; i < dec_len; i += 2) {
        // ignore trailing zeros in result
        while(res_beg <= res_end) {
            if(*res_end != 0) break;
            --res_end;
        }
        // multiplication by 5^25
        sqrt_bin_to_dec();
        // multiplication by 2^25
        shift += 25;
        if(shift >= 64) {
            hi_dec = *(res_beg-1);
            lo_dec = *(res_beg++);
            shift -= 64;
        } else {
            hi_dec = 0;
            lo_dec = *(res_beg-1);
        }
        // extension of result field base
        bas_end += 2;
        // extaction result and splitting into two QWORDs of base field by 13 + 12 decadic figures
        sqrt_split_deci();
        // restriction of the rest fields
        // low significant QWORD (= 64 bit) can be forgotten
        // 9 times during each 10 multiplications by 5^25
        // because 9/10 is slightly less than 25*ln(5)/64*ln(2)
        if(i % 20 > 1) rest[j--] = 0;
    }

    // b2dec time
    DWORD b2dec_time = GetTickCount();

    // print evaluation time(s)
    DWORD time;
    time = binar_time - start_time;
    printf("binar_calc time: %5u.%02u\n",time/1000,time%1000/10);
    time = b2dec_time - binar_time;
    printf("binary2dec time: %5u.%02u\n",time/1000,time%1000/10);
    time = b2dec_time - start_time;
    printf("total_calc time: %5u.%02u\n\n",time/1000,time%1000/10);

    // print the result
    printf("%llu.", base[0]);
    for(i = 1; i < dec_len; i += 2) {
		if(i % 8 == 1) printf("\n");
        printf("%013llu", base[i]);
        printf("%012llu", base[i+1]);
    }
    printf("\n");

    // release memory for the base and the result
    free(base);
    free(rest);

    // print statistics
    printf("\n");
    printf("* binar lead: 0x%016llX\n", lead_stat);
    printf("* binar next: 0x%016llX\n", next_stat);
    for (i = 0; i <= MAX_ADAPT; ++i) {
        printf("* adapt  %llux :   %8llu\n", i, adapt_stat[i]);
    }
    printf("* tot cycles:   %8llu\n", len);

    return 0;
}