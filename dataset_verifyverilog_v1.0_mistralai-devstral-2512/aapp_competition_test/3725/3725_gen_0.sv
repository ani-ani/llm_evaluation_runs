module FrogTimeCalculator(
    input clk,
    input rst_n,
    input start,
    input [15:0] m,
    input [15:0] h1_init,
    input [15:0] a1,
    input [15:0] x1,
    input [15:0] y1,
    input [15:0] h2_init,
    input [15:0] a2,
    input [15:0] x2,
    input [15:0] y2,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [15:0] h1, h2;
    reg [31:0] time;
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2048;
    
    // Memory for cycle detection (using associative memory approach)
    reg [15:0] h1_mem [0:2047];
    reg [15:0] h2_mem [0:2047];
    reg [31:0] time_mem [0:2047];
    reg [11:0] mem_ptr;
    reg cycle_detected;
    
    // Modulo operation helper
    function [15:0] modulo;
        input [31:0] dividend;
        input [15:0] divisor;
        reg [15:0] remainder;
        integer i;
        begin
            remainder = dividend[15:0];
            for (i = 31; i >= 16; i = i - 1) begin
                remainder = {remainder[14:0], dividend[i]};
                if (remainder >= divisor) begin
                    remainder = remainder - divisor;
                end
            end
            modulo = remainder;
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            h1 <= 16'd0;
            h2 <= 16'd0;
            time <= 32'd0;
            cycle_count <= 12'd0;
            mem_ptr <= 12'd0;
            cycle_detected <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_detected <= 1'b0;
                    mem_ptr <= 12'd0;
                    if (start) begin
                        state <= COMPUTE;
                        h1 <= h1_init;
                        h2 <= h2_init;
                        time <= 32'd0;
                        cycle_count <= 12'd0;
                    end
                end
                
                COMPUTE: begin
                    // Check for target condition
                    if (h1 == a1 && h2 == a2) begin
                        state <= FINISH;
                        result <= time;
                    end else begin
                        // Check for cycle detection
                        reg found;
                        integer i;
                        found = 1'b0;
                        for (i = 0; i < mem_ptr; i = i + 1) begin
                            if (h1_mem[i] == h1 && h2_mem[i] == h2) begin
                                found = 1'b1;
                                cycle_detected = 1'b1;
                            end
                        end
                        
                        if (cycle_detected || cycle_count >= MAX_CYCLES - 12'd1) begin
                            state <= FINISH;
                            result <= 32'd4294967295; // -1 in 32-bit signed
                        end else begin
                            // Store current state
                            h1_mem[mem_ptr] <= h1;
                            h2_mem[mem_ptr] <= h2;
                            time_mem[mem_ptr] <= time;
                            mem_ptr <= mem_ptr + 12'd1;
                            
                            // Update heights
                            reg [31:0] temp1, temp2;
                            temp1 = {16'd0, h1} * {16'd0, x1} + {16'd0, y1};
                            temp2 = {16'd0, h2} * {16'd0, x2} + {16'd0, y2};
                            h1 <= modulo(temp1, m);
                            h2 <= modulo(temp2, m);
                            
                            time <= time + 32'd1;
                            cycle_count <= cycle_count + 12'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule