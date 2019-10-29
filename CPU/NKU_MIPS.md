# NKU_MIPS 设计报告

南开大学1队
王理治

## 一、设计简介

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本项目主要设计了一个部分兼容于MIPS32体系结构的CPU，实现了包括大赛要求的57条指令和额外的四条非对齐类Load/Store指令，以及大赛要求的CP0寄存器和异常处理部分。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该处理器采用了经典的五级流水线设计，并实现了数据前递的功能，解决了部分数据冲突导致的流水线停滞问题。

## 二、设计方案

### （一） 总体设计思路

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NKU_MIPS的CPU设计为五级流水，分别为取指(IF)，译码(ID)，执行(EXE)，访存(MEM)和写回(WB)。在取指阶段，将PC寄存器里的值进行虚实地址转换并传输给AXI接口，将从AXI接口读回的指令送入译码阶段。在译码阶段，会对指令的内容进行译码，同时，会从寄存器堆取出需要使用的通用寄存器值。同时，译码阶段也会去判断转移类指令是否发生，如果发生转移则会讲跳转到的PC值送至PC。而译码后得到的指令内容会与得到的寄存器值一起沿着流水线送至执行阶段。在执行阶段，会根据译码结果进行多路选择选择正确的运算结果送往访存阶段。在访存阶段，将会判断当前指令是否为load/store类型指令，如果是的话则会在此阶段向AXI总线发送访存请求，并将所得到的结果传输至写回阶段。在写回阶段进行异常的判断与处理，如果没有发生异常则会进行写寄存器的操作。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于CPU中可能存在的数据冲突采用了数据前递的方法进行处理。在译码阶段如果发现了流水线后面几个阶段存在尚未写入寄存器的数据时，根据不同的指令等待其经过某个特定时期再进行数据前递，例如对于ADD等运算指令可以在其执行周期结束后就进行数据前递，但是对于LW等访存指令则需要等待其访存周期结束后才可以进行数据前递。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于分支指令造成的控制冲突采用延迟槽解决，对于所有的分支指令均存在延迟槽。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;CPU还实现了对精确异常的处理，对于各个阶段产生的异常并不立即处理，而是统一让其随流水线一直推到写回周期进行处理，如果发生了异常则会发送信号给顶层控制单元，并清空流水线，同时设置EPC，并且当异常发生时会停止对数据的访存以及写回操作，确保异常指令不会修改内存和寄存器堆。

### （二）设计流图

@import "../assets/CPUDesign.png"

### （三）取指模块设计

#### 1.取指模块接口

|Name|Width|Direction|Description|
|----|-----|---------|-----------|
|clk|1|In|时钟|
|resetn|1|In|重置，低有效|
|IF_valid|1|In|IF有效信号|
|next_fetch|1|In|进行新PC值的计算|
|inst_addr_ok|1|In|AXI接口地址信号|
|inst_data_ok|1|In|AXI接口数据信号|
|inst|32|In|取回的指令|
|jbr_bus|33|In|分支跳转总线|
|inst_req|1|Out|AXI取指请求信号|
|inst_addr|32|Out|AXI取指请求地址|
|IF_over|1|Out|IF结束信号|
|IF_ID_bus|66|Out|IF_ID总线|
|exc_bus|33|In|异常信号总线|
|is_ds|1|In|是否为延迟槽|
|ID_pc|32|In|回传的译码阶段PC值|
|IF_pc|32|Out|输出当前PC值|
|IF_inst|32|Out|输出当前指令|

#### 2.取指模块设计思路

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;取指模块主要只完成对PC值的正确计算以及根据当前PC值从内存中取出正确的指令。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于前者，正常情况下取指结束后PC值自增4；当有分支跳转指令时，会根据译码周期传来的`jbr_bus`获取到出现需要跳转的信号，从而将PC值置为跳转目的地址；当有异常出现时，会根据写回周期传来的`exc_bus`获取到产生异常的信号，并将PC值置为异常处理入口地址。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于后者，需要根据取指的需求处理有关AXI总线的各个请求信号，即可获得正确指令。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果在取指周期发现PC值未对齐则会产生异常沿着流水线传至写回周期。

### （四）译码模块设计

#### 1.译码模块接口

|Name|Width|Direction|Description|
|----|-----|---------|-----------|
|ID_valid|1|In|ID有效信号|
|IF_ID_bus_r|66|In|IF_ID总线|
|rs_value|32|In|rs寄存器值|
|rt_value|32|In|rt寄存器值|
|rs|5|Out|rs寄存器号|
|rt|5|Out|rt寄存器号|
|jbr_bus|33|Out|分支跳转总线|
|inst_jbr|1|Out|是否为分支跳转指令|
|ID_over|1|Out|ID结束信号|
|ID_EXE_bus|182|Out|ID_EXE总线|
|IF_over|1|In|IF结束信号|
|EXE_over|1|In|EXE结束信号|
|MEM_over|1|In|MEM结束信号|
|EXE_wdest|5|In|处于执行周期指令的目的寄存器|
|MEM_wdest|5|In|处于访存周期指令的目的寄存器|
|WB_wdest|5|In|处于写回周期指令的目的寄存器|
|EXE_result_quick_get|32|In|从执行周期前递的数据|
|MEM_result_quick_get|32|In|从访存周期前递的数据|
|EXE_quick_en|1|In|处于执行周期指令是否允许前递|
|MEM_quick_en|1|In|处于访存周期指令是否允许前递|
|ID_pc|32|Out|输出当前PC值|

#### 2.译码模块设计思路

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;译码模块主要根据取到的指令进行译码操作，并将各个指令根据不同模式进行分类：例如根据指令类型划分运算类指令、访存类指令、跳转指令等；根据rs,rt划分；根据是否存在立即数划分等等。（具体分类方式可以查看译码模块的代码部分。）之后需要根据分类的结果将EXE、MEM、WB所需的信号正确的沿着流水线向后传输
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;其中需要注意有三点：一是前文提到过的数据前递，此处不再赘述；二是对于MIPS的EPC，需要判断当前指令是否处于延迟槽中从而判断是否PC+8，因此此处需要引出`inst_jbr`信号至取指阶段；三是可能会产生保留指令异常，并且会向执行周期传输溢出异常使能信号。

### （五）执行模块设计

#### 1.执行模块接口

|Name|Width|Direction|Description|
|----|-----|---------|-----------|
|EXE_valid|1|In|EXE有效信号|
|ID_EXE_bus_r|182|In|ID_EXE总线|
|EXE_over|1|Out|EXE结束信号|
|EXE_MEM_bus|167|Out|EXE_MEM总线|
|clk|1|In|时钟信号|
|EXE_wdest|5|Out|处于执行周期指令的目的寄存器|
|EXE_result_quick_get|32|Out|从执行周期前递的数据|
|EXE_quick_en|1|Out|处于执行周期指令是否允许前递|
|EXE_pc|32|Out|输出当前PC值|

#### 2.执行模块设计思路

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;执行阶段主要将译码阶段获得到的用于运算的操作码和操作数传入alu以及乘除法模块。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;alu的实现较为简单且均为一拍完成，此处便不再赘述。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;乘法模块采用定点迭代的方法，而除法采用了移位减法的方法，这两者速度均较慢，不过由于乘除法模块较为独立，可在之后随时替换更快速的算法。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当指令可能产生溢出异常时（即：从译码阶段传来的溢出异常使能信号被置位时），可能产生溢出异常

### （六）访存模块设计

#### 1.访存模块接口

|Name|Width|Direction|Description|
|----|-----|---------|-----------|
|clk|1|In|时钟信号|
|resetn|1|In|重置，低有效|
|MEM_valid|1|In|MEM有效信号|
|EXE_MEM_bus_r|167|In|EXE_MEM总线|
|dm_rdata|32|In|访存读回的数据|
|cancel|1|In|异常信号，终止访存|
|data_addr_ok|1|In|AXI接口地址信号|
|data_data_ok|1|In|AXI接口数据信号|
|data_req|1|Out|AXI接口访存请求信号|
|data_wr|1|Out|AXI接口访存读写使能|
|dm_en|1|Out|访存使能信号|
|dm_addr|32|Out|访存地址|
|dm_wen|4|Out|访存写使能|
|dm_wdata|32|Out|访存写数据|
|MEM_over|1|Out|MEM结束信号|
|MEM_WB_bus|161|Out|MEM_WB总线|
|MEM_allow_in|1|In|MEM允许进入信号|
|MEM_wdest|5|Out|处于访存周期指令的目的寄存器|
|MEM_result_quick_get|32|Out|从访存周期前递的数据|
|MEM_quick_en|1|Out|处于访存周期指令是否允许前递|
|MEM_pc|32|Out|输出当前PC值|

#### 1.访存模块设计思路

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;访存阶段主要就是完成访存的工作，与取指部分的AXI接口使用如出一辙。另外值得注意的是，对于SRAM的版本实现了四个非对齐的存取指令的操作，而对于AXI版本，由于AXI总线本身并不支持三字节的处理，暂未完成非对齐指令的扩展。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可能产生存取地址异常。

### （七）写回模块设计

#### 1.写回模块接口

|Name|Width|Direction|Description|
|----|-----|---------|-----------|
|WB_valid|1|In|WB有效信号|
|MEM_WB_bus_r|161|In|MEM_WB总线|
|rf_wen|4|Out|寄存器写使能|
|rf_wdest|5|Out|寄存器写地址|
|rf_wdata|32|Out|寄存器写数据|
|WB_over|1|Out|WB结束信号|
|clk|1|In|时钟信号|
|resetn|1|In|重置，低有效|
|exc_bus|33|Out|异常信号总线|
|WB_wdest|5|Out|处于写回周期指令的目的寄存器|
|cancel|1|Out|异常信号|
|WB_pc|32|Out|输出当前PC值|
|HI_data|32|Out|输出HI寄存器值|
|LO_data|32|Out|输出LO寄存器值|

#### 2.写回模块接口

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;写回阶段整合了CP0，对异常的处理以及关于寄存器堆的写回操作。对于精确异常的实现，也已在前文叙述过了，一旦发现流水线传过来有异常产生，就会发出`cancel`信号中止访存以及写回操作，并记录各个CP0值。

### （八）AXI模块设计

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;AXI模块位于`mycpu_top.v`文件中，将原来的SRAM接口转化成AXI接口，主要实现思路是：优先对写操作进行处理，这样可以避免大多数读写错误。

## 三、设计结果

### （一）设计交付物说明

- 提交目录按大赛要求放置了：
  - SRAM接口的func项目以及产生的`sram_func.bit`文件
  - AXI接口的func项目以及产生的`func.bit`和`memory.bit`文件
  - AXI接口的perf项目以及产生的`perf.bit`文件

### （二）设计演示结果

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;结果已记录在`score.xls`文件中

## 四、参考设计说明

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;参考了龙芯提供的组成原理实验书中的五级流水示例。