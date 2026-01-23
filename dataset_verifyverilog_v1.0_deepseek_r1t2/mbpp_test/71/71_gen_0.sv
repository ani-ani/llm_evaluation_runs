module comb_sort (
    // Clock and control
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input array (8 elements, 8-bit each)
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    
    // Output array (sorted)
    output reg [7:0] sorted_0,
    output reg [7:0] sorted_1,
    output reg [7:0] sorted_2,
    output reg [7:0] sorted_3,
    output reg [7:0] sorted_4,
    output reg [7:0] sorted_5,
    output reg [7:0] sorted_6,
    output reg [7:0] sorted_7,
    
    // Status
    output reg done
);

// State machine states
localparam [1:0] 
    STATE_IDLE  = 2'd0,
    STATE_LOAD  = 2'd1,
    STATE_SORT  = 2'd2,
    STATE_DONE  = 2'd3;

// Internal registers
reg [1:0] state, next_state;
reg [7:0] buffer [0:7];
reg [7:0] gap;
reg swapped;
reg [3:0] i;
reg [5:0] cycle_count;

// Gap calculation helper
wire [7:0] next_gap;
assign next_gap = (gap < 2) ? 8'd0 : 
                 (gap * 10) / 13;  // Better approximation

integer idx;  // Loop index

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (start)
                next_state = STATE_LOAD;
        end
        
        STATE_LOAD: begin
            next_state = STATE_SORT;
        end
        
        STATE_SORT: begin
            if ((gap <= 8'd1 && !swapped) || cycle_count >= 6'd63)
                next_state = STATE_DONE;
            else
                next_state = STATE_SORT;
        end
        
        STATE_DONE: begin
            next_state = STATE_IDLE;
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 1'b0;
        gap <= 8'd0;
        swapped <= 1'b0;
        i <= 4'd0;
        cycle_count <= 6'd0;
        
        for (idx = 0; idx < 8; idx = idx + 1) begin
            buffer[idx] <= 8'd0;
        end
        
        sorted_0 <= 8'd0;
        sorted_1 <= 8'd0;
        sorted_2 <= 8'd0;
        sorted_3 <= 8'd0;
        sorted_4 <= 8'd0;
        sorted_5 <= 8'd0;
        sorted_6 <= 8'd0;
        sorted_7 <= 8'd0;
    end else begin
        state <= next_state;
        
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                cycle_count <= 6'd0;
            end
            
            STATE_LOAD: begin
                buffer[0] <= arr_0;
                buffer[1] <= arr_1;
                buffer[2] <= arr_2;
                buffer[3] <= arr_3;
                buffer[4] <= arr_4;
                buffer[5] <= arr_5;
                buffer[6] <= arr_6;
                buffer[7] <= arr_7;
                
                gap <= 8'd8;
                swapped <= 1'b1;
                i <= 4'd0;
            end
            
            STATE_SORT: begin
                cycle_count <= cycle_count + 6'd1;
                
                if (i < (8 - gap)) begin
                    // Compare and swap
                    if (buffer[i] > buffer[i+gap]) begin
                        buffer[i] <= buffer[i+gap];
                        buffer[i+gap] <= buffer[i];
                        swapped <= 1'b1;
                    end
                    i <= i + 4'd1;
                end else begin
                    // End of pass
                    if (gap > 8'd1) begin
                        gap <= next_gap;
                        swapped <= 1'b0;
                        i <= 4'd0;
                    end else begin
                        swapped <= 1'b0;
                    end
                end
            end
            
            STATE_DONE: begin
                sorted_0 <= buffer[0];
                sorted_1 <= buffer[1];
                sorted_2 <= buffer[2];
                sorted_3 <= buffer[3];
                sorted_4 <= buffer[4];
                sorted_5 <= buffer[5];
                sorted_6 <= buffer[6];
                sorted_7 <= buffer[7];
                done <= 1'b1;
            end
        endcase
    end
end

endmodule