module PortalMovesCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] p_i,
    input wire valid_in,
    input wire [9:0] len,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] M = 32'd1000000007;
    localparam [9:0] MAX_LEN = 10'd1024;
    localparam [10:0] MAX_CYCLES = 11'd4096;

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // State registers
    reg [1:0] state, next_state;
    reg [9:0] index;
    reg [10:0] cycle_count;

    // Memory declarations
    reg [15:0] p_mem [0:1023];
    reg [31:0] dp_mem [0:1023];

    // Intermediate calculation registers
    reg [33:0] temp_add;
    reg [33:0] temp_sub;
    reg [31:0] dp_prev;
    reg [31:0] dp_pi;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 10'd0;
            cycle_count <= 11'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        next_state <= LOAD;
                        index <= 10'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    if (valid_in && index < len) begin
                        p_mem[index] <= p_i;
                        index <= index + 10'd1;
                    end
                    if (index == len) begin
                        next_state <= COMPUTE;
                        index <= 10'd0;
                        // Initialize dp[0] (room 1)
                        dp_mem[0] <= 32'd2;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 11'd1;
                    if (index < len) begin
                        dp_prev <= dp_mem[index];
                        if (p_mem[index] == index + 10'd1) begin
                            temp_add <= dp_prev + 32'd2;
                            dp_mem[index + 10'd1] <= temp_add[31:0];
                        end else begin
                            dp_pi <= dp_mem[p_mem[index] - 10'd1];
                            temp_sub <= (34'd0 + dp_prev + dp_prev) - dp_pi + 32'd2;
                            dp_mem[index + 10'd1] <= temp_sub[31:0];
                        end
                        index <= index + 10'd1;
                    end
                    if (index == len) begin
                        next_state <= FINISH;
                        result <= dp_mem[len];
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                        result <= 32'd0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule