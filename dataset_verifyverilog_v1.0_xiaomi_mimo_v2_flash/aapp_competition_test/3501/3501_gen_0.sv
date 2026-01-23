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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_POS = 3'd1;
    localparam [2:0] COUNT_PAIRS = 3'd2;
    localparam [2:0] FINISHED = 3'd3;

    // State register
    reg [2:0] state;

    // Position arrays - flattened for hardware synthesis
    reg [DATA_WIDTH-1:0] pos1 [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] pos2 [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] pos3 [0:MAX_CAMELS-1];

    // Point arrays for dominance check
    reg [DATA_WIDTH-1:0] points_x [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] points_y [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] points_z [0:MAX_CAMELS-1];

    // Counters and indices
    reg [ADDR_WIDTH-1:0] i;
    reg [ADDR_WIDTH-1:0] j;
    reg [DATA_WIDTH*2-1:0] pair_count;

    // Flags for stage completion
    reg compute_positions_done;
    reg pairs_counting_done;

    // Control signals
    reg [2:0] next_state;

    // State transition logic
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

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= {DATA_WIDTH*2{1'b0}};
            i <= {ADDR_WIDTH{1'b0}};
            j <= {ADDR_WIDTH{1'b0}};
            pair_count <= {DATA_WIDTH*2{1'b0}};
            compute_positions_done <= 1'b0;
            pairs_counting_done <= 1'b0;
            
            // Reset position and point arrays
            for (integer idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                pos1[idx] <= {DATA_WIDTH{1'b0}};
                pos2[idx] <= {DATA_WIDTH{1'b0}};
                pos3[idx] <= {DATA_WIDTH{1'b0}};
                points_x[idx] <= {DATA_WIDTH{1'b0}};
                points_y[idx] <= {DATA_WIDTH{1'b0}};
                points_z[idx] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            state <= next_state;
            
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
                    // Process each camel to compute positions
                    if (i < num_camels) begin
                        // For each position in the race (i is current position being filled)
                        // Jaap's bet: if jaap_bet[idx] == i, then camel at idx is at position i
                        for (integer idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (idx < num_camels) begin
                                if (jaap_bet[idx] < num_camels) begin
                                    if (jaap_bet[idx] == i) begin
                                        pos1[idx] <= i;
                                    end
                                end
                            end
                        end
                        
                        // Jan's bet
                        for (integer idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (idx < num_camels) begin
                                if (jan_bet[idx] < num_camels) begin
                                    if (jan_bet[idx] == i) begin
                                        pos2[idx] <= i;
                                    end
                                end
                            end
                        end
                        
                        // Thijs' bet
                        for (integer idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (idx < num_camels) begin
                                if (thijs_bet[idx] < num_camels) begin
                                    if (thijs_bet[idx] == i) begin
                                        pos3[idx] <= i;
                                    end
                                end
                            end
                        end
                        
                        i <= i + 1'b1;
                    end else begin
                        // Build points array sorted by x (pos1)
                        // Since pos1 contains camel indices sorted by Jaap's race order
                        // we need to map camel index to point
                        for (integer idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (idx < num_camels) begin
                                // pos1[idx] is the position of camel idx
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
                    // Count dominance pairs using nested loops
                    // For all pairs (i, j), count if points[i] dominates points[j]
                    if (i < num_camels) begin
                        if (j < num_camels) begin
                            if (i != j) begin
                                // Check if points[i] dominates points[j]
                                if ((points_x[i] < points_x[j]) && 
                                    (points_y[i] < points_y[j]) && 
                                    (points_z[i] < points_z[j])) begin
                                    pair_count <= pair_count + 1'b1;
                                end
                            end
                            j <= j + 1'b1;
                        end else begin
                            i <= i + 1'b1;
                            j <= {ADDR_WIDTH{1'b0}};
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