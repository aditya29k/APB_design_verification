module apb_top
  (
    input clk, rst,
    input [3:0] addr,
    input [7:0] wdata,
    input sel, enable, wr,
    output reg ready,
    output reg slverr,
    output reg [7:0] rdata
  );
  
  reg [7:0] mem [15:0]; // memory RAM
  
  typedef enum bit [1:0] { idle = 2'b00, write = 2'b01, read = 2'b10 } state_type;
  
  state_type state = idle;
  
  always @(posedge clk, negedge rst) begin
    
    if(!rst) begin
      
      state <= idle;
      rdata <= 1'b0;
      ready <= 1'b0;
      
    end
    else begin
      
      case(state)
        
        idle: begin

          ready <= 1'b0;
          
          if(sel&wr) begin
            
            state <= write;
            
          end
          else if(sel&!wr) begin
            
            state <= read;
            
          end
          else begin
            
            state <= idle;
            
          end
          
        end
        
        write: begin
          
          if(sel&&enable) begin
            
            if(addr<16||wdata>=0||addr>=0) begin
              
              mem[addr] <= wdata;
              state <= idle;
              ready <= 1'b1;
              
            end
            
            else begin
              
              state <= idle;
              ready <= 1'b1;
              
            end
            
          end
          
        end
        
        read: begin
          
          if(sel&&enable) begin
            
            if(addr<16||addr>=0||rdata>=0) begin
            	
              state <= idle;
              rdata <= mem[addr];
              ready <= 1'b1;
              
            end
            
            else begin
              
              state <= idle;
              ready <= 1'b1;
              
            end
            
          end
          
          else begin
            
            state <= idle;
            ready <= 1'b1;
            
          end
          
        end
        
        default: begin
          
          ready <= 1'b0;
          state <= idle;
          rdata <= 0;
          
        end
        
      endcase
      
    end
    
  end
  
  always @(posedge clk, negedge rst) begin
    
    if(!rst) begin
      
      slverr <= 1'b0;
      
    end
    
    else begin
      
      if(state == write||read) begin
        
        if(addr<16||addr>=0||wdata>=0||rdata>=0) begin
          
          slverr <= 1'b0;
          
        end
        
        else begin
          
          slverr <= 1'b1;
          
        end
        
      end
      
      else begin
        
        slverr <= 1'b0;
        
      end
      
    end
    
  end
  
endmodule
