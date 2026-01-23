module partition_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] c,
    input wire edge_valid,
    input wire [1:0] edge_a,
    input wire [1:0] edge_b,
    input wire [5:0] edge_y,
    output wire edge_ready,
    output wire result_valid,
    output wire [15:0] year,
    output wire done
);
    
    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMP = 2'd2;
    localparam [1:0] DONE = 2'd3;
    reg [1:0] state;
    
    // Edge storage
    reg [2:0] edge_cnt;
    reg [1:0] edge_a_reg [0:5];
    reg [1:0] edge_b_reg [0:5];
    reg [5:0] edge_y_reg [0:5];
    
    // Computation registers
    reg [5:0] Y_offset;
    reg [2:0] edge_idx;
    reg [15:0] early;
    reg found;
    reg [15:0] result_year_reg;
    reg edge_ready_reg;
    reg result_valid_reg;
    reg building;
    
    // Helper wires for early matrix rows
    wire [3:0] early_row0 = early[3:0];
    wire [3:0] early_row1 = early[7:4];
    wire [3:0] early_row2 = early[11:8];
    wire [3:0] early_row3 = early[15:12];
    
    // Valid partition check for n=4 (size 2 groups)
    wire valid_partition = 
        (early_row0[1] && !early_row2[3]) ||
        (early_row0[2] && !early_row1[3]) ||
        (early_row0[3] && !early_row1[2]) ||
        (early_row1[2] && !early_row0[3]) ||
        (early_row1[3] && !early_row0[2]) ||
        (early_row2[3] && !early_row0[1]);
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_cnt <= 3'd0;
            Y_offset <= 6'd0;
            edge_idx <= 3'd0;
            early <= 16'd0;
            found <= 1'b0;
            result_year_reg <= 16'd0;
            edge_ready_reg <= 1'b0;
            result_valid_reg <= 1'b0;
            building <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    edge_ready_reg <= 1'b1;
                    result_valid_reg <= 1'b0;
                    if (start) begin
                        edge_cnt <= 3'd0;
                        Y_offset <= 6'd0;
                        found <= 1'b0;
                        building <= 1'b0;
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    edge_ready_reg <= 1'b1;
                    if (edge_valid && edge_cnt < c) begin
                        edge_a_reg[edge_cnt] <= edge_a;
                        edge_b_reg[edge_cnt] <= edge_b;
                        edge_y_reg[edge_cnt] <= edge_y;
                        edge_cnt <= edge_cnt + 3'd1;
                        if (edge_cnt + 3'd1 == c) begin
                            state <= COMP;
                            edge_ready_reg <= 1'b0;
                            building <= 1'b1;
                            edge_idx <= 3'd0;
                            early <= 16'd0;
                        end
                    end
                end
                
                COMP: begin
                    if (building) begin
                        // Build early matrix for current Y_offset
                        if (edge_idx < c) begin
                            if (edge_y_reg[edge_idx] < Y_offset) begin
                                early[edge_a_reg[edge_idx]*4 + edge_b_reg[edge_idx]] <= 1'b1;
                                early[edge_b_reg[edge_idx]*4 + edge_a_reg[edge_idx]] <= 1'b1;
                            end
                            edge_idx <= edge_idx + 3'd1;
                        end else begin
                            building <= 1'b0;
                        end
                    end else begin
                        // Check if partition exists
                        if (valid_partition) begin
                            found <= 1'b1;
                            result_year_reg <= 16'd1948 + Y_offset;
                            state <= DONE;
                        end else if (Y_offset < 6'd60) begin
                            Y_offset <= Y_offset + 6'd1;
                            building <= 1'b1;
                            edge_idx <= 3'd0;
                            early <= 16'd0;
                        end else begin
                            found <= 1'b0;
                            result_year_reg <= 16'd0;
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    result_valid_reg <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Output assignments
    assign edge_ready = edge_ready_reg && (state == LOAD);
    assign result_valid = result_valid_reg;
    assign done = result_valid_reg;
    assign year = result_year_reg;
    
endmodule