module stick_sorter (
    input clk,
    input rst_n,
    input start,
    // Inputs for 8 sticks: each stick has 4 coordinates (x1, y1, x2, y2)
    input [15:0] s0_x1, s0_y1, s0_x2, s0_y2,
    input [15:0] s1_x1, s1_y1, s1_x2, s1_y2,
    input [15:0] s2_x1, s2_y1, s2_x2, s2_y2,
    input [15:0] s3_x1, s3_y1, s3_x2, s3_y2,
    input [15:0] s4_x1, s4_y1, s4_x2, s4_y2,
    input [15:0] s5_x1, s5_y1, s5_x2, s5_y2,
    input [15:0] s6_x1, s6_y1, s6_x2, s6_y2,
    input [15:0] s7_x1, s7_y1, s7_x2, s7_y2,
    input [2:0] n_sticks,
    output reg [3:0] order_0,
    output reg [3:0] order_1,
    output reg [3:0] order_2,
    output reg [3:0] order_3,
    output reg [3:0] order_4,
    output reg [3:0] order_5,
    output reg [3:0] order_6,
    output reg [3:0] order_7,
    output reg done
);

    // Internal registers
    reg [2:0] state;
    reg [7:0] removed;
    reg [7:0] dep_matrix [0:7];
    reg [3:0] current_order [0:7];
    reg [3:0] next_stick;
    reg [3:0] count;

    // State encoding
    localparam IDLE = 3'b000;
    localparam COMPUTE_DEPS = 3'b001;
    localparam FIND_NEXT = 3'b010;
    localparam UPDATE_REMOVED = 3'b011;
    localparam DONE = 3'b100;

    // Stick coordinates array for easier access
    wire [15:0] sticks_x1 [0:7] = '{s0_x1, s1_x1, s2_x1, s3_x1, s4_x1, s5_x1, s6_x1, s7_x1};
    wire [15:0] sticks_y1 [0:7] = '{s0_y1, s1_y1, s2_y1, s3_y1, s4_y1, s5_y1, s6_y1, s7_y1};
    wire [15:0] sticks_x2 [0:7] = '{s0_x2, s1_x2, s2_x2, s3_x2, s4_x2, s5_x2, s6_x2, s7_x2};
    wire [15:0] sticks_y2 [0:7] = '{s0_y2, s1_y2, s2_y2, s3_y2, s4_y2, s5_y2, s6_y2, s7_y2};

    // Calculate average y for each stick
    wire [15:0] avg_y [0:7];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : avg_y_gen
            assign avg_y[i] = (sticks_y1[i] + sticks_y2[i]) / 2;
        end
    endgenerate

    // Calculate min and max x for each stick
    wire [15:0] min_x [0:7];
    wire [15:0] max_x [0:7];
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : min_max_x_gen
            assign min_x[j] = (sticks_x1[j] < sticks_x2[j]) ? sticks_x1[j] : sticks_x2[j];
            assign max_x[j] = (sticks_x1[j] > sticks_x2[j]) ? sticks_x1[j] : sticks_x2[j];
        end
    endgenerate

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            removed <= 8'b0;
            count <= 4'b0;
            done <= 1'b0;
            next_stick <= 4'b0;
            order_0 <= 4'b0;
            order_1 <= 4'b0;
            order_2 <= 4'b0;
            order_3 <= 4'b0;
            order_4 <= 4'b0;
            order_5 <= 4'b0;
            order_6 <= 4'b0;
            order_7 <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE_DEPS;
                    end
                end
                COMPUTE_DEPS: begin
                    state <= FIND_NEXT;
                end
                FIND_NEXT: begin
                    if (next_stick != 4'b0) begin
                        state <= UPDATE_REMOVED;
                    end else if (count == n_sticks) begin
                        state <= DONE;
                    end
                end
                UPDATE_REMOVED: begin
                    state <= FIND_NEXT;
                end
                DONE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Compute dependency matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                dep_matrix[i] <= 8'b0;
            end
        end else if (state == COMPUTE_DEPS) begin
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (i != j && i < n_sticks && j < n_sticks) begin
                        // Check overlap
                        reg overlap = (max_x[i] >= min_x[j]) && (min_x[i] <= max_x[j]);
                        // Check height
                        reg higher = (avg_y[i] > avg_y[j]);
                        dep_matrix[i][j] <= overlap && higher;
                    end else begin
                        dep_matrix[i][j] <= 1'b0;
                    end
                end
            end
        end
    end

    // Find next stick to remove
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_stick <= 4'b0;
        end else if (state == FIND_NEXT) begin
            next_stick <= 4'b0;
            for (i = 0; i < 8; i = i + 1) begin
                if (!removed[i] && i < n_sticks) begin
                    reg no_deps = 1'b1;
                    for (j = 0; j < 8; j = j + 1) begin
                        if (dep_matrix[j][i] && !removed[j] && j < n_sticks) begin
                            no_deps = 1'b0;
                        end
                    end
                    if (no_deps) begin
                        next_stick <= i;
                    end
                end
            end
        end
    end

    // Update removed and order
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            removed <= 8'b0;
            count <= 4'b0;
        end else if (state == UPDATE_REMOVED && next_stick != 4'b0) begin
            removed[next_stick] <= 1'b1;
            current_order[count] <= next_stick;
            count <= count + 1;
            // Update dependency matrix: remove dependencies from the removed stick
            for (j = 0; j < 8; j = j + 1) begin
                dep_matrix[next_stick][j] <= 1'b0;
            end
        end
    end

    // Output the order
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            order_0 <= 4'b0;
            order_1 <= 4'b0;
            order_2 <= 4'b0;
            order_3 <= 4'b0;
            order_4 <= 4'b0;
            order_5 <= 4'b0;
            order_6 <= 4'b0;
            order_7 <= 4'b0;
        end else if (state == DONE) begin
            order_0 <= current_order[0];
            order_1 <= current_order[1];
            order_2 <= current_order[2];
            order_3 <= current_order[3];
            order_4 <= current_order[4];
            order_5 <= current_order[5];
            order_6 <= current_order[6];
            order_7 <= current_order[7];
        end
    end

endmodule