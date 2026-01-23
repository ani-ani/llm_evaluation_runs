module ski_probability(
    input clk,
    input rst_n,
    input start,
    input [31:0] ski_prob_01,
    input [31:0] ski_prob_02,
    input [31:0] ski_prob_03,
    input [31:0] ski_prob_12,
    input [31:0] ski_prob_13,
    input [31:0] ski_prob_23,
    input walk_edge_01,
    input walk_edge_02,
    input walk_edge_03,
    input walk_edge_12,
    input walk_edge_13,
    input walk_edge_23,
    output reg [31:0] prob_k0,
    output reg [31:0] prob_k1,
    output reg [31:0] prob_k2,
    output reg [31:0] prob_k3,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] SKI_PROP   = 3'd2;
    localparam [2:0] WALK_PROP  = 3'd3;
    localparam [2:0] NEXT_K     = 3'd4;
    localparam [2:0] COMPUTE_FINAL = 3'd5;
    localparam [2:0] OUTPUT     = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state;
    reg [1:0] k;  // Current walk count (0-3)
    reg [3:0] edge_idx;  // Edge iteration index (0-5)
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // dp array: dp[node][k]
    // Using separate registers for each entry for Icarus compatibility
    reg [31:0] dp_0_0, dp_0_1, dp_0_2, dp_0_3;
    reg [31:0] dp_1_0, dp_1_1, dp_1_2, dp_1_3;
    reg [31:0] dp_2_0, dp_2_1, dp_2_2, dp_2_3;
    reg [31:0] dp_3_0, dp_3_1, dp_3_2, dp_3_3;

    // Temporary registers for multiplication
    reg [31:0] mult_a;
    reg [31:0] mult_b;
    wire [63:0] mult_result;
    assign mult_result = {32'd0, mult_a} * {32'd0, mult_b};
    wire [31:0] product;
    assign product = mult_result[47:16];

    // Intermediate comparison registers
    reg [31:0] temp_val;
    reg [31:0] max_val;

    // Final probability registers
    reg [31:0] best0, best1, best2, best3;
    reg [1:0] final_step;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k <= 2'd0;
            edge_idx <= 4'd0;
            cycle_counter <= 8'd0;
            done <= 1'b0;
            
            // Initialize all dp entries
            dp_0_0 <= 32'd0; dp_0_1 <= 32'd0; dp_0_2 <= 32'd0; dp_0_3 <= 32'd0;
            dp_1_0 <= 32'd0; dp_1_1 <= 32'd0; dp_1_2 <= 32'd0; dp_1_3 <= 32'd0;
            dp_2_0 <= 32'd0; dp_2_1 <= 32'd0; dp_2_2 <= 32'd0; dp_2_3 <= 32'd0;
            dp_3_0 <= 32'd0; dp_3_1 <= 32'd0; dp_3_2 <= 32'd0; dp_3_3 <= 32'd0;
            
            prob_k0 <= 32'd0;
            prob_k1 <= 32'd0;
            prob_k2 <= 32'd0;
            prob_k3 <= 32'd0;
            
            best0 <= 32'd0;
            best1 <= 32'd0;
            best2 <= 32'd0;
            best3 <= 32'd0;
            final_step <= 2'd0;
            
            mult_a <= 32'd0;
            mult_b <= 32'd0;
            temp_val <= 32'd0;
            max_val <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize dp[0][0] = 1.0 (Q16.16)
                    dp_0_0 <= 32'h0001_0000;
                    // All others already 0 from reset
                    k <= 2'd0;
                    edge_idx <= 4'd0;
                    state <= SKI_PROP;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                SKI_PROP: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    case (edge_idx)
                        4'd0: begin  // (0,1)
                            if (ski_prob_01 != 32'd0) begin
                                case (k)
                                    2'd0: begin mult_a <= dp_0_0; mult_b <= ski_prob_01; end
                                    2'd1: begin mult_a <= dp_0_1; mult_b <= ski_prob_01; end
                                    2'd2: begin mult_a <= dp_0_2; mult_b <= ski_prob_01; end
                                    2'd3: begin mult_a <= dp_0_3; mult_b <= ski_prob_01; end
                                endcase
                                // Update will happen in next cycle
                                temp_val <= dp_1_0; // Hold current for comparison
                            end
                        end
                        4'd1: begin  // (0,2)
                            if (ski_prob_02 != 32'd0) begin
                                case (k)
                                    2'd0: begin mult_a <= dp_0_0; mult_b <= ski_prob_02; end
                                    2'd1: begin mult_a <= dp_0_1; mult_b <= ski_prob_02; end
                                    2'd2: begin mult_a <= dp_0_2; mult_b <= ski_prob_02; end
                                    2'd3: begin mult_a <= dp_0_3; mult_b <= ski_prob_02; end
                                endcase
                                temp_val <= dp_2_0;
                            end
                        end
                        4'd2: begin  // (0,3)
                            if (ski_prob_03 != 32'd0) begin
                                case (k)
                                    2'd0: begin mult_a <= dp_0_0; mult_b <= ski_prob_03; end
                                    2'd1: begin mult_a <= dp_0_1; mult_b <= ski_prob_03; end
                                    2'd2: begin mult_a <= dp_0_2; mult_b <= ski_prob_03; end
                                    2'd3: begin mult_a <= dp_0_3; mult_b <= ski_prob_03; end
                                endcase
                                temp_val <= dp_3_0;
                            end
                        end
                        4'd3: begin  // (1,2)
                            if (ski_prob_12 != 32'd0) begin
                                case (k)
                                    2'd0: begin mult_a <= dp_1_0; mult_b <= ski_prob_12; end
                                    2'd1: begin mult_a <= dp_1_1; mult_b <= ski_prob_12; end
                                    2'd2: begin mult_a <= dp_1_2; mult_b <= ski_prob_12; end
                                    2'd3: begin mult_a <= dp_1_3; mult_b <= ski_prob_12; end
                                endcase
                                temp_val <= dp_2_0;
                            end
                        end
                        4'd4: begin  // (1,3)
                            if (ski_prob_13 != 32'd0) begin
                                case (k)
                                    2'd0: begin mult_a <= dp_1_0; mult_b <= ski_prob_13; end
                                    2'd1: begin mult_a <= dp_1_1; mult_b <= ski_prob_13; end
                                    2'd2: begin mult_a <= dp_1_2; mult_b <= ski_prob_13; end
                                    2'd3: begin mult_a <= dp_1_3; mult_b <= ski_prob_13; end
                                endcase
                                temp_val <= dp_3_0;
                            end
                        end
                        4'd5: begin  // (2,3)
                            if (ski_prob_23 != 32'd0) begin
                                case (k)
                                    2'd0: begin mult_a <= dp_2_0; mult_b <= ski_prob_23; end
                                    2'd1: begin mult_a <= dp_2_1; mult_b <= ski_prob_23; end
                                    2'd2: begin mult_a <= dp_2_2; mult_b <= ski_prob_23; end
                                    2'd3: begin mult_a <= dp_2_3; mult_b <= ski_prob_23; end
                                endcase
                                temp_val <= dp_3_0;
                            end
                        end
                    endcase
                    
                    // Check for max and update
                    if (edge_idx == 4'd0) begin
                        // Update (0,1) -> node 1
                        if (ski_prob_01 != 32'd0 && product > dp_1_0) begin
                            case (k)
                                2'd0: dp_1_0 <= product;
                                2'd1: dp_1_1 <= product;
                                2'd2: dp_1_2 <= product;
                                2'd3: dp_1_3 <= product;
                            endcase
                        end
                    end else if (edge_idx == 4'd1) begin
                        // Update (0,2) -> node 2
                        if (ski_prob_02 != 32'd0 && product > dp_2_0) begin
                            case (k)
                                2'd0: dp_2_0 <= product;
                                2'd1: dp_2_1 <= product;
                                2'd2: dp_2_2 <= product;
                                2'd3: dp_2_3 <= product;
                            endcase
                        end
                    end else if (edge_idx == 4'd2) begin
                        // Update (0,3) -> node 3
                        if (ski_prob_03 != 32'd0 && product > dp_3_0) begin
                            case (k)
                                2'd0: dp_3_0 <= product;
                                2'd1: dp_3_1 <= product;
                                2'd2: dp_3_2 <= product;
                                2'd3: dp_3_3 <= product;
                            endcase
                        end
                    end else if (edge_idx == 4'd3) begin
                        // Update (1,2) -> node 2
                        if (ski_prob_12 != 32'd0 && product > dp_2_0) begin
                            case (k)
                                2'd0: dp_2_0 <= product;
                                2'd1: dp_2_1 <= product;
                                2'd2: dp_2_2 <= product;
                                2'd3: dp_2_3 <= product;
                            endcase
                        end
                    end else if (edge_idx == 4'd4) begin
                        // Update (1,3) -> node 3
                        if (ski_prob_13 != 32'd0 && product > dp_3_0) begin
                            case (k)
                                2'd0: dp_3_0 <= product;
                                2'd1: dp_3_1 <= product;
                                2'd2: dp_3_2 <= product;
                                2'd3: dp_3_3 <= product;
                            endcase
                        end
                    end else if (edge_idx == 4'd5) begin
                        // Update (2,3) -> node 3
                        if (ski_prob_23 != 32'd0 && product > dp_3_0) begin
                            case (k)
                                2'd0: dp_3_0 <= product;
                                2'd1: dp_3_1 <= product;
                                2'd2: dp_3_2 <= product;
                                2'd3: dp_3_3 <= product;
                            endcase
                        end
                    end

                    if (edge_idx < 4'd5) begin
                        edge_idx <= edge_idx + 4'd1;
                    end else begin
                        edge_idx <= 4'd0;
                        state <= WALK_PROP;
                    end
                end

                WALK_PROP: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    case (edge_idx)
                        4'd0: begin  // (0,1)
                            if (walk_edge_01) begin
                                // Update k+1 from k
                                case (k)
                                    2'd0: begin
                                        // dp_1_1 = max(dp_1_1, dp_0_0)
                                        if (dp_0_0 > dp_1_1) dp_1_1 <= dp_0_0;
                                        // dp_0_1 = max(dp_0_1, dp_1_0)
                                        if (dp_1_0 > dp_0_1) dp_0_1 <= dp_1_0;
                                    end
                                    2'd1: begin
                                        // dp_1_2 = max(dp_1_2, dp_0_1)
                                        if (dp_0_1 > dp_1_2) dp_1_2 <= dp_0_1;
                                        // dp_0_2 = max(dp_0_2, dp_1_1)
                                        if (dp_1_1 > dp_0_2) dp_0_2 <= dp_1_1;
                                    end
                                    2'd2: begin
                                        // dp_1_3 = max(dp_1_3, dp_0_2)
                                        if (dp_0_2 > dp_1_3) dp_1_3 <= dp_0_2;
                                        // dp_0_3 = max(dp_0_3, dp_1_2)
                                        if (dp_1_2 > dp_0_3) dp_0_3 <= dp_1_2;
                                    end
                                endcase
                            end
                        end
                        4'd1: begin  // (0,2)
                            if (walk_edge_02) begin
                                case (k)
                                    2'd0: begin
                                        if (dp_0_0 > dp_2_1) dp_2_1 <= dp_0_0;
                                        if (dp_2_0 > dp_0_1) dp_0_1 <= dp_2_0;
                                    end
                                    2'd1: begin
                                        if (dp_0_1 > dp_2_2) dp_2_2 <= dp_0_1;
                                        if (dp_2_1 > dp_0_2) dp_0_2 <= dp_2_1;
                                    end
                                    2'd2: begin
                                        if (dp_0_2 > dp_2_3) dp_2_3 <= dp_0_2;
                                        if (dp_2_2 > dp_0_3) dp_0_3 <= dp_2_2;
                                    end
                                endcase
                            end
                        end
                        4'd2: begin  // (0,3)
                            if (walk_edge_03) begin
                                case (k)
                                    2'd0: begin
                                        if (dp_0_0 > dp_3_1) dp_3_1 <= dp_0_0;
                                        if (dp_3_0 > dp_0_1) dp_0_1 <= dp_3_0;
                                    end
                                    2'd1: begin
                                        if (dp_0_1 > dp_3_2) dp_3_2 <= dp_0_1;
                                        if (dp_3_1 > dp_0_2) dp_0_2 <= dp_3_1;
                                    end
                                    2'd2: begin
                                        if (dp_0_2 > dp_3_3) dp_3_3 <= dp_0_2;
                                        if (dp_3_2 > dp_0_3) dp_0_3 <= dp_3_2;
                                    end
                                endcase
                            end
                        end
                        4'd3: begin  // (1,2)
                            if (walk_edge_12) begin
                                case (k)
                                    2'd0: begin
                                        if (dp_1_0 > dp_2_1) dp_2_1 <= dp_1_0;
                                        if (dp_2_0 > dp_1_1) dp_1_1 <= dp_2_0;
                                    end
                                    2'd1: begin
                                        if (dp_1_1 > dp_2_2) dp_2_2 <= dp_1_1;
                                        if (dp_2_1 > dp_1_2) dp_1_2 <= dp_2_1;
                                    end
                                    2'd2: begin
                                        if (dp_1_2 > dp_2_3) dp_2_3 <= dp_1_2;
                                        if (dp_2_2 > dp_1_3) dp_1_3 <= dp_2_2;
                                    end
                                endcase
                            end
                        end
                        4'd4: begin  // (1,3)
                            if (walk_edge_13) begin
                                case (k)
                                    2'd0: begin
                                        if (dp_1_0 > dp_3_1) dp_3_1 <= dp_1_0;
                                        if (dp_3_0 > dp_1_1) dp_1_1 <= dp_3_0;
                                    end
                                    2'd1: begin
                                        if (dp_1_1 > dp_3_2) dp_3_2 <= dp_1_1;
                                        if (dp_3_1 > dp_1_2) dp_1_2 <= dp_3_1;
                                    end
                                    2'd2: begin
                                        if (dp_1_2 > dp_3_3) dp_3_3 <= dp_1_2;
                                        if (dp_3_2 > dp_1_3) dp_1_3 <= dp_3_2;
                                    end
                                endcase
                            end
                        end
                        4'd5: begin  // (2,3)
                            if (walk_edge_23) begin
                                case (k)
                                    2'd0: begin
                                        if (dp_2_0 > dp_3_1) dp_3_1 <= dp_2_0;
                                        if (dp_3_0 > dp_2_1) dp_2_1 <= dp_3_0;
                                    end
                                    2'd1: begin
                                        if (dp_2_1 > dp_3_2) dp_3_2 <= dp_2_1;
                                        if (dp_3_1 > dp_2_2) dp_2_2 <= dp_3_1;
                                    end
                                    2'd2: begin
                                        if (dp_2_2 > dp_3_3) dp_3_3 <= dp_2_2;
                                        if (dp_3_2 > dp_2_3) dp_2_3 <= dp_3_2;
                                    end
                                endcase
                            end
                        end
                    endcase
                    
                    if (edge_idx < 4'd5) begin
                        edge_idx <= edge_idx + 4'd1;
                    end else begin
                        edge_idx <= 4'd0;
                        state <= NEXT_K;
                    end
                end

                NEXT_K: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (k < 2'd3) begin
                        k <= k + 2'd1;
                        state <= SKI_PROP;
                    end else begin
                        state <= COMPUTE_FINAL;
                    end
                end

                COMPUTE_FINAL: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    case (final_step)
                        2'd0: begin
                            best0 <= dp_3_0;
                            final_step <= 2'd1;
                        end
                        2'd1: begin
                            if (dp_3_0 > dp_3_1)
                                best1 <= dp_3_0;
                            else
                                best1 <= dp_3_1;
                            final_step <= 2'd2;
                        end
                        2'd2: begin
                            if (best1 > dp_3_2)
                                best2 <= best1;
                            else
                                best2 <= dp_3_2;
                            final_step <= 2'd3;
                        end
                        2'd3: begin
                            if (best2 > dp_3_3)
                                best3 <= best2;
                            else
                                best3 <= dp_3_3;
                            state <= OUTPUT;
                        end
                    endcase
                end

                OUTPUT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    prob_k0 <= best0;
                    prob_k1 <= best1;
                    prob_k2 <= best2;
                    prob_k3 <= best3;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter safety
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule