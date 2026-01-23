module multi_concat #(
    parameter NUM_ELEMENTS = 8,
    parameter ELEMENT_WIDTH = 8,
    parameter RESULT_WIDTH = 64
  ) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [ELEMENT_WIDTH-1:0] arr [NUM_ELEMENTS-1:0],
    input wire [3:0] len,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
  );

  localparam IDLE = 1'b0;
  localparam PROCESS = 1'b1;
  
  reg state;
  reg [3:0] idx;
  reg processing;
  reg [RESULT_WIDTH-1:0] temp_result;
  
  function [7:0] to_decimal;
    input [7:0] val;
    reg [7:0] abs_val;
    reg [3:0] tens, units;
    begin
        abs_val = val[7] ? (~val + 1'b1) : val;
        if (abs_val > 8'd99) 
            abs_val = 8'd99;
        tens = abs_val / 8'd10;
        units = abs_val % 8'd10;
        to_decimal = {tens, units};
    end
  endfunction
  
  wire is_negative;
  assign is_negative = (len > 4'd0) && arr[0][7];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 64'd0;
        done <= 1'b0;
        idx <= 4'd0;
        processing <= 1'b0;
        temp_result <= 64'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start && !processing) begin
                    processing <= 1'b1;
                    temp_result <= 64'd0;
                    if (is_negative) 
                        temp_result[63] <= 1'b1;
                    else 
                        temp_result[63] <= 1'b0;
                    idx <= 4'd0;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                if (idx < len) begin
                    integer shift_amt;
                    reg [7:0] val_to_convert;
                    reg [7:0] decimal_val;
                    
                    shift_amt = is_negative ? 
                        (RESULT_WIDTH - 8 - (8 * idx) - 1) : 
                        (RESULT_WIDTH - 8 - (8 * idx));
                    
                    if (idx == 4'd0 && is_negative) 
                        val_to_convert = ~arr[0] + 1'b1;
                    else 
                        val_to_convert = arr[idx];
                    
                    decimal_val = to_decimal(val_to_convert);
                    
                    temp_result <= temp_result | (decimal_val << shift_amt);
                    idx <= idx + 4'd1;
                end else begin
                    result <= temp_result;
                    done <= 1'b1;
                    processing <= 1'b0;
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
  end
  
endmodule