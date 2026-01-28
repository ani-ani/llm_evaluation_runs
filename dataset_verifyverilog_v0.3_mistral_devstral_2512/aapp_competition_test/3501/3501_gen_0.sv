module camel_race #(
    parameter MAX_CAMELS = 8,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] jaap_bet [0:MAX_CAMELS-1],
    input wire [DATA_WIDTH-1:0] jan_bet [0:MAX_CAMELS-1],
    input wire [DATA_WIDTH-1:0] thijs_bet [0:MAX_CAMELS-1],
    input wire [ADDR_WIDTH-1:0] num_camels,
    output reg [DATA_WIDTH*2-1:0] result,
    output reg done
);

    // Internal state definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_POS = 2'd1;
    localparam [1:0] COUNT_PAIRS = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // State register
    reg [1:0] state, next_state;

    // Position arrays
    reg [DATA_WIDTH-1:0] pos1 [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] pos2 [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] pos3 [0:MAX_CAMELS-1];

    // Point array for CDQ algorithm (x, y, z)
    reg [DATA_WIDTH-1:0] points_x [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] points_y [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] points_z [0:MAX_CAMELS-1];

    // Counters and indices
    reg [ADDR_WIDTH-1:0] i, j;
    reg [DATA_WIDTH*2-1:0] pair_count;

    // Control signals
    reg compute_positions_done;
    reg pairs_counting_done;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_POS;
                else next_state = IDLE;
            end
            COMPUTE_POS: begin
                if (compute_positions_done) next_state = COUNT_PAIRS;
                else next_state = COMPUTE_POS;
            end
            COUNT_PAIRS: begin
                if (pairs_counting_done) next_state = FINISHED;
                else next_state = COUNT_PAIRS;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            result <= {DATA_WIDTH*2{1'b0}};
            i <= {ADDR_WIDTH{1'b0}};
            j <= {ADDR_WIDTH{1'b0}};
            pair_count <= {DATA_WIDTH*2{1'b0}};
            compute_positions_done <= 1'b0;
            pairs_counting_done <= 1'b0;
            
            // Reset position arrays
            integer idx;
            for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                pos1[idx] <= {DATA_WIDTH{1'b0}};
                pos2[idx] <= {DATA_WIDTH{1'b0}};
                pos3[idx] <= {DATA_WIDTH{1'b0}};
                points_x[idx] <= {DATA_WIDTH{1'b0}};
                points_y[idx] <= {DATA_WIDTH{1'b0}};
                points_z[idx] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= {ADDR_WIDTH{1'b0}};
                        j <= {ADDR_WIDTH{1'b0}};
                        pair_count <= {DATA_WIDTH*2{1'b0}};
                        compute_positions_done <= 1'b0;
                        pairs_counting_done <= 1'b0;
                    end
                end

                COMPUTE_POS: begin
                    // Convert bets to position arrays
                    if (i < num_camels) begin
                        // Position for Jaap's bet
                        integer idx;
                        for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (jaap_bet[idx] < num_camels && jaap_bet[idx] < MAX_CAMELS) begin
                                pos1[jaap_bet[idx]] <= i;
                            end
                        end
                        // Position for Jan's bet
                        for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (jan_bet[idx] < num_camels && jan_bet[idx] < MAX_CAMELS) begin
                                pos2[jan_bet[idx]] <= i;
                            end
                        end
                        // Position for Thijs' bet
                        for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (thijs_bet[idx] < num_camels && thijs_bet[idx] < MAX_CAMELS) begin
                                pos3[thijs_bet[idx]] <= i;
                            end
                        end
                        i <= i + 1'b1;
                    end else begin
                        // Build points array sorted by x (pos1)
                        integer idx;
                        for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (idx < num_camels) begin
                                points_x[idx] <= pos1[idx];
                                points_y[idx] <= pos2[idx];
                                points_z[idx] <= pos3[idx];
                            end
                        end
                        compute_positions_done <= 1'b1;
                        i <= {ADDR_WIDTH{1'b0}};
                        j <= {ADDR_WIDTH{1'b0}};
                    end
                end

                COUNT_PAIRS: begin
                    // Simplified CDQ algorithm for fixed small N
                    if (i < num_camels) begin
                        j <= {ADDR_WIDTH{1'b0}};
                        if (j < num_camels && j != i) begin
                            // Check if points[i] dominates points[j]
                            if ((points_x[i] < points_x[j]) && 
                                (points_y[i] < points_y[j]) && 
                                (points_z[i] < points_z[j])) begin
                                pair_count <= pair_count + 1'b1;
                            end
                            // Also check the reverse (points[j] dominates points[i])
                            if ((points_x[j] < points_x[i]) && 
                                (points_y[j] < points_y[i]) && 
                                (points_z[j] < points_z[i])) begin
                                pair_count <= pair_count + 1'b1;
                            end
                            j <= j + 1'b1;
                        end else begin
                            i <= i + 1'b1;
                        end
                    end else begin
                        pairs_counting_done <= 1'b1;
                    end
                end

                FINISHED: begin
                    result <= pair_count;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule