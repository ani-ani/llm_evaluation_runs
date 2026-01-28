module array_modulo(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr1_in [0:7],
    input wire [7:0] arr2_in [0:7],
    output reg [7:0] result_out [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] index;  // 3 bits for 0-7
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Modulo operation function
    function [7:0] compute_mod;
        input [7:0] a, b;
        reg [7:0] remainder;
        integer i;
        begin
            remainder = a;
            for (i = 0; i < 8; i = i + 1) begin
                if (remainder >= b) begin
                    remainder = remainder - b;
                end
            end
            compute_mod = remainder;
        end
    endfunction

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            
            COMPUTE: begin
                if (index == len - 1 || cycle_count >= MAX_CYCLES)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            // Initialize result array
            result_out[0] <= 8'd0;
            result_out[1] <= 8'd0;
            result_out[2] <= 8'd0;
            result_out[3] <= 8'd0;
            result_out[4] <= 8'd0;
            result_out[5] <= 8'd0;
            result_out[6] <= 8'd0;
            result_out[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute modulo for current index
                    result_out[index] <= compute_mod(arr1_in[index], arr2_in[index]);
                    
                    // Increment index
                    if (index < len - 1 && cycle_count < MAX_CYCLES)
                        index <= index + 3'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule