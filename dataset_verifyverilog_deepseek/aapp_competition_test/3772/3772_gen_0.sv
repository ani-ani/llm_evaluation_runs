module resistance_calculator(    
  input clk,                    
  input rst_n,                  
  input start,                  
  input [15:0] a,               
  input [15:0] b,               
  output reg [15:0] result,     
  output reg done               
);                               
                                 
  localparam [1:0] IDLE = 0,    
               COMPUTE = 1,     
               DONE = 2;        
  reg [1:0] state;              
  reg [15:0] x_reg, y_reg;      
  reg [15:0] count_reg;         
                                 
  always_ff @(posedge clk or negedge rst_n) begin 
    if (~rst_n) begin            
      state <= IDLE;             
      done <= 1'b0;              
      result <= 16'b0;           
      x_reg <= 16'b0;            
      y_reg <= 16'b0;            
      count_reg <= 16'b0;        
    end                          
    else begin                   
      done <= 1'b0;              
      case (state)               
        IDLE: begin              
          if (start) begin       
            x_reg <= a;          
            y_reg <= b;          
            count_reg <= 16'b0;  
            state <= COMPUTE;    
          end                    
        end                      
                                  
        COMPUTE: begin           
          if (y_reg != 0) begin  
            count_reg <= count_reg + (x_reg / y_reg); 
            x_reg <= y_reg;      
            y_reg <= x_reg % y_reg; 
          end                    
          else begin             
            result <= count_reg; 
            state <= DONE;       
          end                    
        end                      
                                  
        DONE: begin              
          done <= 1'b1;          
          if (start) state <= IDLE; 
        end                      
      endcase                    
    end                          
  end                            
endmodule                        