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
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_POS = 3'd1;
    localparam [2:0] COUNT_PAIRS = 3'd2;
    localparam [2:0] FINISHED = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Position arrays
    reg [DATA_WIDTH-1:0] pos1 [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] pos2 [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] pos3 [0:MAX_CAMELS-1];
    
    // Points arrays
    reg [DATA_WIDTH-1:0] points_x [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] points_y [0:MAX_CAMELS-1];
    reg [DATA_WIDTH-1:0] points_z [0:MAX_CAMELS-1];
    
    // Counters
    reg [ADDR_WIDTH-1:0] i, j;
    reg [DATA_WIDTH*2-1:0] pair_count;
    reg compute_done;
    
    // Safe maximum cycles
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
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
            IDLE: next_state = start ? COMPUTE_POS : IDLE;
            COMPUTE_POS: next_state = (compute_done && (cycle_count < MAX_CYCLES)) ? COUNT_PAIRS : COMPUTE_POS;
            COUNT_PAIRS: next_state = (j >= num_camels - 1 && i >= num_camels - 1) ? FINISHED : COUNT_PAIRS;
            FINISHED: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    integer idx;
    
    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers and arrays
            done <= 1'b0;
            result <= {DATA_WIDTH*2{1'b0}};
            i <= {ADDR_WIDTH{1'b0}};
            j <= {ADDR_WIDTH{1'b0}};
            pair_count <= {DATA_WIDTH*2{1'b0}};
            compute_done <= 1'b0;
            cycle_count <= 8'd0;
            
            for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                pos1[idx] <= {DATA_WIDTH{1'b0}};
                pos2[idx] <= {DATA_WIDTH{1'b0}};
                pos3[idx] <= {DATA_WIDTH{1'b0}};
                points_x[idx] <= {DATA_WIDTH{1'b0}};
                points_y[idx] <= {DATA_WIDTH{1'b0}};
                points_z[idx] <= {DATA_WIDTH{1'b0}};
            end
        end 
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Reset counters
                        i <= {ADDR_WIDTH{1'b0}};
                        j <= {ADDR_WIDTH{1'b0}};
                        pair_count <= {DATA_WIDTH*2{1'b0}};
                        compute_done <= 1'b0;
                    end
                end
                
                COMPUTE_POS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i < num_camels) begin
                        pos1[jaap_bet[i]] <= i;
                        pos2[jan_bet[i]] <= i;
                        pos3[thijs_bet[i]] <= i;
                        i <= i + 1;
                    end
                    
                    if (i == num_camels) begin
                        // Populate points arrays
                        for (idx = 0; idx < MAX_CAMELS; idx = idx + 1) begin
                            if (idx < num_camels) begin
                                points_x[idx] <= pos1[idx];
                                points_y[idx] <= pos2[idx];
                                points_z[idx] <= pos3[idx];
                            end
                        end
                        compute_done <= 1'b1;
                        i <= 0;
                    end
                end
                
                COUNT_PAIRS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i < num_camels - 1) begin
                        if (j < num_camels) begin
                            if (j > i) begin
                                if ((points_x[i] < points_x[j]) && 
                                    (points_y[i] < points_y[j]) && 
                                    (points_z[i] < points_z[j])) begin
                                    pair_count <= pair_count + 1;
                                end
                                
                                if ((points_x[j] < points_x[i]) && 
                                    (points_y[j] < points_y[i]) && 
                                    (points_z[j] < points_z[i])) begin
                                    pair_count <= pair_count + 1;
                                end
                            end
                            j <= j + 1;
                        end
                        else begin
                            j <= i + 1;
                            i <= i + 1;
                        end
                    end
                end
                
                FINISHED: begin
                    result <= pair_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule