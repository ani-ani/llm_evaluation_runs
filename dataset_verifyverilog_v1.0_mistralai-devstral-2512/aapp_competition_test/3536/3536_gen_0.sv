module heap_probability (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input wire [15:0] b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15,
    input wire [3:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [3:0] p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE = 4'd1;
    localparam [3:0] FINISH = 4'd2;

    reg [3:0] state;
    reg [3:0] current_node;
    reg [31:0] current_prob;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // Register arrays for b and p values
    reg [15:0] b_reg [0:15];
    reg [3:0] p_reg [0:15];

    // Initialize arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 4'd0;
            current_prob <= 32'd0;
            cycle_count <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                b_reg[i] <= 16'd0;
                p_reg[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Load input values into registers
                        b_reg[0] <= b_0; b_reg[1] <= b_1; b_reg[2] <= b_2; b_reg[3] <= b_3;
                        b_reg[4] <= b_4; b_reg[5] <= b_5; b_reg[6] <= b_6; b_reg[7] <= b_7;
                        b_reg[8] <= b_8; b_reg[9] <= b_9; b_reg[10] <= b_10; b_reg[11] <= b_11;
                        b_reg[12] <= b_12; b_reg[13] <= b_13; b_reg[14] <= b_14; b_reg[15] <= b_15;
                        p_reg[0] <= p_0; p_reg[1] <= p_1; p_reg[2] <= p_2; p_reg[3] <= p_3;
                        p_reg[4] <= p_4; p_reg[5] <= p_5; p_reg[6] <= p_6; p_reg[7] <= p_7;
                        p_reg[8] <= p_8; p_reg[9] <= p_9; p_reg[10] <= p_10; p_reg[11] <= p_11;
                        p_reg[12] <= p_12; p_reg[13] <= p_13; p_reg[14] <= p_14; p_reg[15] <= p_15;
                        current_prob <= 32'd256; // Q8.8 representation of 1.0
                        current_node <= 4'd1; // Start from node 1 (root is node 0)
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (current_node < n && current_node != 4'd0) begin
                        // Get parent and child b values
                        reg [3:0] parent_idx = p_reg[current_node];
                        reg [15:0] b_child = b_reg[current_node];
                        reg [15:0] b_parent = b_reg[parent_idx];
                        reg [31:0] prob_edge;

                        // Calculate edge probability
                        if (b_child <= b_parent) begin
                            prob_edge = (b_child << 8) / (2 * b_parent);
                        end else begin
                            prob_edge = (b_parent << 8) / (2 * b_child);
                        end

                        // Multiply with current probability (Q8.8)
                        current_prob = (current_prob * prob_edge) >> 8;
                        current_node <= current_node + 4'd1;
                    end

                    // Check if all nodes processed or max cycles reached
                    if (current_node >= n || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= current_prob;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule