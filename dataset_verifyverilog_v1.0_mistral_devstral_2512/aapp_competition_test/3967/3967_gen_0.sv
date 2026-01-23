module BambooMaxInterval(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] a [0:7],
    input [15:0] k,
    output reg [7:0] max_d,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] ITERATE_D  = 3'd1;
    localparam [2:0] COMPUTE_SUM = 3'd2;
    localparam [2:0] CHECK      = 3'd3;
    localparam [2:0] UPDATE     = 3'd4;
    localparam [2:0] COMPLETE   = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] current_d;
    reg [15:0] total_cut;
    reg [2:0] bamboo_index;
    reg [7:0] ceil_val;
    reg [15:0] cut_amount;
    reg [7:0] temp_max_d;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_d <= 8'd0;
            total_cut <= 16'd0;
            bamboo_index <= 3'd0;
            ceil_val <= 8'd0;
            cut_amount <= 16'd0;
            temp_max_d <= 8'd0;
            max_d <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= ITERATE_D;
                        current_d <= 8'd1;
                        temp_max_d <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                ITERATE_D: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= COMPLETE;
                    end else if (current_d == 8'd256) begin
                        next_state <= COMPLETE;
                    end else begin
                        total_cut <= 16'd0;
                        bamboo_index <= 3'd0;
                        next_state <= COMPUTE_SUM;
                    end
                end

                COMPUTE_SUM: begin
                    if (bamboo_index < n) begin
                        // Compute ceil(a_i/d) = (a_i + d - 1)/d
                        ceil_val <= (a[bamboo_index] + current_d - 8'd1) / current_d;
                        // Compute cut amount = ceil(a_i/d)*d - a_i
                        cut_amount <= (ceil_val * current_d) - a[bamboo_index];
                        total_cut <= total_cut + cut_amount;
                        bamboo_index <= bamboo_index + 3'd1;
                        next_state <= COMPUTE_SUM;
                    end else begin
                        next_state <= CHECK;
                    end
                end

                CHECK: begin
                    if (total_cut <= k) begin
                        next_state <= UPDATE;
                    end else begin
                        next_state <= ITERATE_D;
                        current_d <= current_d + 8'd1;
                    end
                end

                UPDATE: begin
                    temp_max_d <= current_d;
                    next_state <= ITERATE_D;
                    current_d <= current_d + 8'd1;
                end

                COMPLETE: begin
                    max_d <= temp_max_d;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule