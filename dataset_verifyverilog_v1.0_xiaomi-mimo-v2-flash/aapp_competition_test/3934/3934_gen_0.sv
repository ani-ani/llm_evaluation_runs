module CheckTreeEdges (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [4:0] edge_u [0:18],
    input wire [4:0] edge_v [0:18],
    input wire [18:0] edge_valid,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_DEG  = 3'd1;
    localparam [2:0] PROC_EDGE = 3'd2;
    localparam [2:0] SCAN_DEG  = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] degrees [0:19];  // degree for nodes 1-20 (index 0-19)
    reg [4:0] i;  // index for edges (0-18)
    reg [4:0] j;  // index for nodes (0-19)
    reg found_degree_2;  // flag for detection
    reg [4:0] n_reg;  // store n for processing
    
    // Initialize all degree registers and internal state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 5'd0;
            j <= 5'd0;
            found_degree_2 <= 1'b0;
            n_reg <= 5'd0;
            degrees[0] <= 5'd0;
            degrees[1] <= 5'd0;
            degrees[2] <= 5'd0;
            degrees[3] <= 5'd0;
            degrees[4] <= 5'd0;
            degrees[5] <= 5'd0;
            degrees[6] <= 5'd0;
            degrees[7] <= 5'd0;
            degrees[8] <= 5'd0;
            degrees[9] <= 5'd0;
            degrees[10] <= 5'd0;
            degrees[11] <= 5'd0;
            degrees[12] <= 5'd0;
            degrees[13] <= 5'd0;
            degrees[14] <= 5'd0;
            degrees[15] <= 5'd0;
            degrees[16] <= 5'd0;
            degrees[17] <= 5'd0;
            degrees[18] <= 5'd0;
            degrees[19] <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 5'd0;
                    j <= 5'd0;
                    found_degree_2 <= 1'b0;
                    if (start) begin
                        n_reg <= (n > 5'd20) ? 5'd20 : n[4:0];
                        // Handle edge cases
                        if (n <= 5'd1) begin
                            result <= 1'b1;  // YES for n <= 1
                        end
                    end
                end
                
                INIT_DEG: begin
                    // Initialize degree for node j (0-based index)
                    if (j < 5'd20) begin
                        degrees[j] <= 5'd0;
                        j <= j + 5'd1;
                    end
                end
                
                PROC_EDGE: begin
                    if (i < 5'd19) begin
                        // Process edge i if valid
                        if (edge_valid[i]) begin
                            // Increment degree for u (convert to 0-based index)
                            if (edge_u[i] >= 5'd1 && edge_u[i] <= n_reg) begin
                                degrees[edge_u[i] - 5'd1] <= degrees[edge_u[i] - 5'd1] + 5'd1;
                            end
                            // Increment degree for v (convert to 0-based index)
                            if (edge_v[i] >= 5'd1 && edge_v[i] <= n_reg) begin
                                degrees[edge_v[i] - 5'd1] <= degrees[edge_v[i] - 5'd1] + 5'd1;
                            end
                        end
                        i <= i + 5'd1;
                    end
                end
                
                SCAN_DEG: begin
                    if (j < n_reg) begin
                        // Check if any node has degree == 2
                        if (degrees[j] == 5'd2) begin
                            found_degree_2 <= 1'b1;
                        end
                        j <= j + 5'd1;
                    end
                end
                
                FINISH: begin
                    // Set result based on found_degree_2 flag
                    result <= ~found_degree_2;  // YES if no degree 2, NO otherwise
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (n <= 5'd1) begin
                        next_state = FINISH;  // Immediate finish for edge cases
                    end else begin
                        next_state = INIT_DEG;  // Start initialization
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            INIT_DEG: begin
                if (j < 5'd20) begin
                    next_state = INIT_DEG;  // Continue initializing
                end else begin
                    next_state = PROC_EDGE;  // Move to edge processing
                end
            end
            
            PROC_EDGE: begin
                if (i < 5'd19) begin
                    next_state = PROC_EDGE;  // Continue processing edges
                end else begin
                    next_state = SCAN_DEG;   // Move to degree scan
                end
            end
            
            SCAN_DEG: begin
                if (j < n_reg) begin
                    next_state = SCAN_DEG;  // Continue scanning
                end else begin
                    next_state = FINISH;    // Move to finish
                end
            end
            
            FINISH: begin
                next_state = IDLE;  // Return to idle after done
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule