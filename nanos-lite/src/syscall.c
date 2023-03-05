#include <common.h>
#include "syscall.h"//syscall.h在lite和apps里都声明了。注意统一性
#include <fs.h>//关于系统调用函数的实现
#include <sys/time.h>//时间结构体库
#include <am.h>
#include <proc.h>

extern void naive_uload(PCB *pcb, const char *filename);

/*/3.4前的sysy_write通过串口发送的版本，现在不用了
static size_t sys_write(size_t fd, const void *buf, size_t count) {
  if (fd == 1 || fd == 2) {
    for (size_t i = 0; i < count; i ++) {
      putch(((char *)buf)[i]);
    }
    return count;
  }
  else {
     return fs_write(fd, (void *)buf, count);
  }

}*/


void do_syscall(Context *c) {

}
