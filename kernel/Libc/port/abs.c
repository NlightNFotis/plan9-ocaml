#include <u.h>
#include <libc.h>

int
abs(int a)
{
    if(a < 0)
        return -a;
    return a;
}

