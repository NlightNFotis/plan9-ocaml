#include <u.h>
#include <libc.h>
#include <draw.h>
#include <memdraw.h>
#include <memlayer.h>

/*
 * Pull i towards top of screen, just behind front
*/
static
void
_memltofront(Memimage *i, Memimage *front, bool fill)
{
    Memlayer *l;
    Memscreen *s;
    Memimage *f;
    Rectangle x;
    bool overlap;
    Memimage *ff, *rr;

    l = i->layer;
    s = l->screen;

    while(l->front != front){
        f = l->front;
        x = l->screenr;

        // i will now pass in front of f, so hide f
        overlap = rectclip(&x, f->layer->screenr);
        if(overlap){
            memlhide(f, x);
            f->layer->clear = false;
        }
        /* swap l and f in screen's list */
        // swap_double_list(l, f, s->frontmost, s->rearmost)
        ff = f->layer->front;
        rr = l->rear;

        if(ff == nil)
            s->frontmost = i;
        else
            ff->layer->rear = i;

        if(rr == nil)
            s->rearmost = f;
        else
            rr->layer->front = f;

        l->front = ff;
        l->rear = f; // f is now behind i
        f->layer->front = i;
        f->layer->rear = rr;
        if(overlap && fill)
            memlexpose(i, x);
    }
}

void
_memltofrontfill(Memimage *i, bool fill)
{
    _memltofront(i, nil, fill);
    _memlsetclear(i->layer->screen);
}

void
memltofront(Memimage *i)
{
    _memltofront(i, nil, true);
    _memlsetclear(i->layer->screen);
}

void
memltofrontn(Memimage **ip, int n)
{
    Memimage *i, *front;

    if(n == 0)
        return;
    front = nil;
    while(--n >= 0){
        i = *ip++;
        _memltofront(i, front, true);
        front = i;
    }
    _memlsetclear(front->layer->screen);
}
