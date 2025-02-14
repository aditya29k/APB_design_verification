interface apb_intf;
  
  logic clk, rst;
  logic wr;
  logic sel, enable;
  logic [7:0] wdata;
  logic [3:0] addr;
  logic slverr;
  logic ready;
  logic [7:0] rdata;
  
endinterface

class transaction;
  
  rand bit wr;
  rand bit [3:0] addr;
  rand bit [7:0] wdata;
  
  bit sel, enable;
  bit ready;
  bit slverr;
  bit [7:0] rdata;
  
  function transaction copy();
    
    copy = new();
    copy.wr = this.wr;
    copy.addr = this.addr;
    copy.wdata = this.wdata;
    copy.sel = this.sel;
    copy.enable = this.enable;
    copy.ready = this.ready;
    copy.slverr = this.slverr;
    copy.rdata = this.rdata;
    
  endfunction
  
  constraint wr_cons { wr dist { 1:= 50, 0:= 50}; }
  constraint wdata_cons { wr == 1'b0 -> wdata == 0; }
  //constraint addr_cons { addr<2; } test constraint 
  
endclass

class generator;
  
  transaction t;
  mailbox #(transaction) mbx;
  mailbox #(transaction) reff;
  
  event parnext;
  event done;
  
  int count;
  
  function new(mailbox #(transaction) mbx, mailbox #(transaction) reff);
    
    this.mbx = mbx;
    this.reff = reff;
    t = new();
    
  endfunction
  
  task run();
    
    repeat(count) begin
      
      $display("---------------");
      assert(t.randomize) else $display("[GEN] Randomization Failed");
      $display("[GEN] wr: %0d, addr: %0d, wdata: %0d", t.wr, t.addr, t.wdata);
      mbx.put(t.copy());
      reff.put(t.copy());
      @(parnext);
      
    end
    ->done;
    
  endtask
  
  
endclass

class driver;
  
  transaction t;
  mailbox #(transaction) mbx;
  
  virtual apb_intf intf;
  
  event parnext;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    
  endfunction
  
  task reset();
    
    intf.rst <= 1'b0;
    intf.wr <= 1'b0;
    intf.sel <= 1'b0;
    intf.enable <= 1'b0;
    intf.addr <= 0;
    intf.wdata <= 0;
    repeat(10)@(posedge intf.clk);
    intf.rst <= 1'b1;
    $display("[DRV] SYSTEM RESET COMPLETE");
    $display("-----------------------");
    @(posedge intf.clk);
    
  endtask
  
  task run();
    
    forever begin
      
      mbx.get(t);
      intf.wr <= t.wr;
      if(intf.wr) begin
        
        intf.sel <= 1'b1;
        intf.enable <= 1'b0;
        intf.wdata <= t.wdata;
        intf.addr <= t.addr;
        @(posedge intf.clk);
        intf.enable <= 1'b1;
        $display("[DRV] addr: %0d, wdata: %0d, enable:%0d", intf.addr, intf.wdata, intf.enable);
        @(posedge intf.clk);
        intf.enable <= 1'b0;
        intf.sel <= 1'b0;
        intf.wr <= 1'b0;
        //->parnext;
        
      end
      
      else begin
        
        intf.sel <= 1'b1;
        intf.enable <= 1'b0;
        intf.wdata <= t.wdata;
        intf.addr <= t.addr;
        @(posedge intf.clk);
        intf.enable <= 1'b1;
        $display("[DRV] addr: %0d, enable:%0d", intf.addr, intf.enable);
        @(posedge intf.clk);
        intf.enable <= 1'b0;
        intf.wr <= 1'b0;
        intf.sel <= 1'b0;
        //->parnext;
        
      end
      
    end
    
  endtask
  
endclass

class monitor;
  
  transaction t;
  mailbox #(transaction) mbx_ms;
  
  virtual apb_intf intf;
  
  event parnext;
  
  function new(mailbox #(transaction) mbx_ms);
    
    this.mbx_ms = mbx_ms;
    
  endfunction
  
  task run();
    
    t = new();
    forever begin

      @(posedge intf.ready);
      t.wr = intf.wr;
      t.addr = intf.addr;
      t.wdata = intf.wdata;
      t.rdata = intf.rdata;
      t.ready = intf.ready;
      $display("[MON] wr: %0d, addr: %0d, wdata: %0d, rdata: %0d, ready: %0d", t.wr, t.addr, t.wdata, t.rdata, t.ready);
      mbx_ms.put(t);
      @(posedge intf.clk);

      //->parnext;
      
    end
    
  endtask
  
endclass

class scoreboard;
  
  transaction t;
  transaction t_reff;
  mailbox #(transaction) reff;
  mailbox #(transaction) mbx_ms;
  
  bit [7:0] mem [15:0];
  
  bit [7:0] temp;
  
  event parnext;
  
  function new(mailbox #(transaction) reff, mailbox #(transaction) mbx_ms);
    
    this.reff = reff;
    this.mbx_ms = mbx_ms;
    
  endfunction
  
  task run();
    
    forever begin
      
      mbx_ms.get(t);
      reff.get(t_reff);
      if( t_reff.wr == 1'b1 ) begin
        
        mem[t_reff.addr] = t_reff.wdata;
        $display("[SCO] DATA ADDED");
        
      end
      
      else begin
        
        temp = mem[t_reff.addr];
        
        if(temp == t.rdata) begin
          
          $display("[SCO] DATA MATCHED");
          
        end
        
        else begin
          
          $display("[SCO] DATA MISMATCHED");
          
        end
        
      end
      
      ->parnext;
      
    end
    
  endtask
  
endclass

class environment;
  
  transaction t;
  generator g;
  driver d;
  monitor m;
  scoreboard s;
  
  mailbox #(transaction) mbx;
  mailbox #(transaction) reff;
  mailbox #(transaction) mbx_ms;
  
  virtual apb_intf intf;
  
  event done;
  
  function new(virtual apb_intf intf);
    
    mbx = new();
    reff = new();
    mbx_ms = new();
    
    t = new();
    g = new(mbx, reff);
    d = new(mbx);
    m = new(mbx_ms);
    s = new(reff, mbx_ms);
    
    this.intf = intf;
    d.intf = this.intf;
    m.intf = this.intf;
    
    g.done = done;
    g.parnext = s.parnext;
    
    g.count = 15;
    
  endfunction
  
  task pre_test();
    
    d.reset();
    
  endtask
  
  task test();
    
    fork
      
      g.run();
      d.run();
      m.run();
      s.run();
      
    join_any
    
  endtask
  
  task post_test();
    
    wait(done.triggered);
    $finish();
    
  endtask
  
  task run();
    
    pre_test();
    test();
    post_test();
    
  endtask
  
endclass

module tb;
  
  environment env;
  
  apb_intf intf();
  
  apb_top DUT (.clk(intf.clk), .rst(intf.rst), .addr(intf.addr), .wdata(intf.wdata), .sel(intf.sel), .enable(intf.enable), .wr(intf.wr), .ready(intf.ready), .slverr(intf.slverr), .rdata(intf.rdata));
  
  initial begin
    
    intf.clk <= 1'b0;
    
  end
  
  always #10 intf.clk <= ~intf.clk;
  
  initial begin
    
    env = new(intf);
    env.run();
    
  end
  
  initial begin
    
    $dumpfile("dump.vcd");
    $dumpvars;
    
  end
  
endmodule
