module ratio_splitter_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    input wire [31:0] c_in,
    input wire [31:0] d_in,
    output reg done,
    output reg [7:0] node_count,
    output reg [7:0] left_child,
    output reg [7:0] right_child,
    output reg output_valid,
    output reg [7:0] current_node
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [31:0] a_reg, b_reg, c_reg, d_reg;
    reg [31:0] c_temp, d_temp;
    reg [7:0] node_idx;
    reg [7:0] stack_ptr;
    reg [7:0] output_idx;

    // Node storage (max 200 nodes)
    reg [7:0] left_child_mem [0:199];
    reg [7:0] right_child_mem [0:199];

    // Cycle counter to prevent infinite loops
    reg [16:0] cycle_count;
    localparam [16:0] MAX_CYCLES = 17'd20000;

    // GCD calculation function
    function [31:0] gcd(input [31:0] x, input [31:0] y);
        reg [31:0] a, b, temp;
        begin
            a = x;
            b = y;
            while (b != 0) begin
                temp = b;
                b = a % b;
                a = temp;
            end
            gcd = a;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            node_count <= 8'd0;
            left_child <= 8'd0;
            right_child <= 8'd0;
            output_valid <= 1'b0;
            current_node <= 8'd0;
            node_idx <= 8'd0;
            stack_ptr <= 8'd0;
            output_idx <= 8'd0;
            cycle_count <= 17'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (c_temp == 32'd0 || d_temp == 32'd0 || node_idx >= 8'd200 || cycle_count >= MAX_CYCLES) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                if (output_idx >= node_count) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 32'd0;
            b_reg <= 32'd0;
            c_reg <= 32'd0;
            d_reg <= 32'd0;
            c_temp <= 32'd0;
            d_temp <= 32'd0;
        end else begin
            case (state)
                INIT: begin
                    a_reg <= a_in;
                    b_reg <= b_in;
                    c_reg <= c_in;
                    d_reg <= d_in;

                    // Normalize ratios
                    if (a_reg != 0 && b_reg != 0) begin
                        c_temp <= c_reg / gcd(c_reg, d_reg);
                        d_temp <= d_reg / gcd(c_reg, d_reg);
                    end else begin
                        c_temp <= c_reg;
                        d_temp <= d_reg;
                    end

                    node_idx <= 8'd0;
                    stack_ptr <= 8'd0;
                    output_idx <= 8'd0;
                    cycle_count <= 17'd0;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 1'b1;

                    if (c_temp >= a_reg) begin
                        // Route to left child
                        left_child_mem[node_idx] <= node_idx + 1'b1;
                        right_child_mem[node_idx] <= 8'd255; // Terminal
                        c_temp <= c_temp - a_reg;
                        node_idx <= node_idx + 1'b1;
                    end else if (d_temp >= b_reg) begin
                        // Route to right child
                        left_child_mem[node_idx] <= 8'd254; // Terminal
                        right_child_mem[node_idx] <= node_idx + 1'b1;
                        d_temp <= d_temp - b_reg;
                        node_idx <= node_idx + 1'b1;
                    end else begin
                        // Terminal case
                        left_child_mem[node_idx] <= 8'd254;
                        right_child_mem[node_idx] <= 8'd255;
                        node_idx <= node_idx + 1'b1;
                    end
                end

                OUTPUT: begin
                    if (output_idx < node_count) begin
                        current_node <= output_idx;
                        left_child <= left_child_mem[output_idx];
                        right_child <= right_child_mem[output_idx];
                        output_valid <= 1'b1;
                        output_idx <= output_idx + 1'b1;
                    end else begin
                        output_valid <= 1'b0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                    output_valid <= 1'b0;
                end
            endcase
        end
    end

    // Update node count when computation completes
    always @(posedge clk) begin
        if (state == COMPUTE && (c_temp == 32'd0 || d_temp == 32'd0 || node_idx >= 8'd200 || cycle_count >= MAX_CYCLES)) begin
            node_count <= node_idx;
        end
    end

    // Clear done signal after one cycle
    always @(posedge clk) begin
        if (state == DONE) begin
            done <= 1'b0;
        end
    end

endmodule