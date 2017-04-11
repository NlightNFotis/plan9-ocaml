#include <u.h>
#include <libc.h>
#include <draw.h>
#include <memdraw.h>
#include <pool.h>

void
memimagemove(void *from, void *to)
{
    Memdata *md;

    md = *(Memdata**)to;
    if(md->base != from){
        print("compacted data not right: #%p\n", md->base);
        abort();
    }
    md->base = to;

    /* if allocmemimage changes this must change too */
    md->bdata = (byte*)md->base + sizeof(Memdata*) + sizeof(ulong);
}

Memimage*
allocmemimaged(Rectangle r, ulong chan, Memdata *md)
{
    int d;
    ulong l;
    Memimage *i;

    if(Dx(r) <= 0 || Dy(r) <= 0){
        werrstr("bad rectangle %R", r);
        return nil;
    }
    d = chantodepth(chan);
    if(d == 0) {
        werrstr("bad channel descriptor %.8lux", chan);
        return nil;
    }
    l = wordsperline(r, d);

    i = mallocz(sizeof(Memimage), true);
    if(i == nil)
        return nil;

    i->data = md;
    i->zero = sizeof(ulong) * l * r.min.y;
    if(r.min.x >= 0)
        i->zero += (r.min.x*d)/8;
    else
        i->zero -= (-r.min.x*d+7)/8;
    i->zero = -i->zero;
    i->width = l;
    i->r = r;
    i->clipr = r;
    i->flags = 0;

    i->layer = nil;
    i->cmap = memdefcmap;

    if(memsetchan(i, chan) < 0){
        free(i);
        return nil;
    }
    return i;
}


Memimage*
allocmemimage(Rectangle r, ulong chan)
{
    int d;
    byte *p;
    ulong l, nw;
    Memdata *md;
    Memimage *i;

    d = chantodepth(chan);
    if(d == 0) {
        werrstr("bad channel descriptor %.8lux", chan);
        return nil;
    }

    l = wordsperline(r, d);
    nw = l * Dy(r);

    md = malloc(sizeof(Memdata));
    if(md == nil)
        return nil;
    md->ref = 1;
    // the big alloc!
    md->base = poolalloc(imagmem, sizeof(Memdata*)+(1+nw)*sizeof(ulong));
    if(md->base == nil){
        free(md);
        return nil;
    }

    p = (byte*)md->base;
    *(Memdata**)p = md;
    p += sizeof(Memdata*);
    *(ulong*)p = getcallerpc(&r);
    p += sizeof(ulong);

    /* if this changes, memimagemove must change too */
    md->bdata = p;
    md->allocd = true;

    i = allocmemimaged(r, chan, md);
    if(i == nil){
        poolfree(imagmem, md->base);
        free(md);
        return nil;
    }

    return i;
}

void
freememimage(Memimage *i)
{
    if(i == nil)
        return;
    // free the Memdata
    if(i->data->ref-- == 1 && i->data->allocd){
        if(i->data->base)
            poolfree(imagmem, i->data->base);
        free(i->data);
    }
    free(i);
}

