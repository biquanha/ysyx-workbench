/*#include "trap.h"*/
#include <am.h>
#include <klib.h>
#include <klib-macros.h>

static Context* do_event(Event e, Context* c) {
  switch (e.event) {
    case(EVENT_YIELD) : printf("EVENT_YIELD\n"); break;
    case(EVENT_SYSCALL) :break;
    default: printf("Unhandled event ID = %d", e.event);assert(0);
  }

  return c;
}

int main()
{
    asm volatile("li t1, 42949679104" : :);
    asm volatile("csrw mstatus, t1" : :);
    asm volatile("csrr t0, mstatus" : :);

    asm volatile("csrr t0, mtvec" : :);
    asm volatile("csrr t0, mcause" : :);
    asm volatile("csrr t0, mepc" : :);

    cte_init(do_event);
    asm volatile("csrr t0, mtvec" : :);

    asm volatile("li t2, 11" : :);
    asm volatile("csrw mcause, t2" : :);
    asm volatile("csrr t0, mcause" : :);

    asm volatile("li t2, 8" : :);
    asm volatile("csrw mepc, t2" : :);
    asm volatile("csrr t0, mepc" : :);

    asm volatile("ecall");

    return 0;
}

