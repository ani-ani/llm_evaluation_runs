module MaxCoolSubmatrix(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [11:0] matrix_flat [0:8],
    output reg [5:0] max_area,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    localparam DATA_WIDTH = 12;
    localparam AREA_WIDTH = 6;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    reg [5:0] max_area_next;
    reg done_next;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_area <= 6'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute max_area_next combinational
                    max_area_next = 6'd0;
                    
                    // Iterate over all submatrices
                    integer i, j, k, l;
                    reg signed [DATA_WIDTH-1:0] submatrix [0:2][0:2];
                    reg is_monge;
                    reg [5:0] current_area;
                    
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            for (k = i; k < 3; k = k + 1) begin
                                for (l = j; l < 3; l = l + 1) begin
                                    // Extract submatrix
                                    submatrix[0][0] = matrix_flat[i*3 + j];
                                    submatrix[0][1] = matrix_flat[i*3 + l];
                                    submatrix[1][0] = matrix_flat[k*3 + j];
                                    submatrix[1][1] = matrix_flat[k*3 + l];
                                    
                                    // Check Monge condition
                                    is_monge = 1'b1;
                                    if (submatrix[0][0] + submatrix[1][1] < submatrix[0][1] + submatrix[1][0]) begin
                                        is_monge = 1'b0;
                                    end
                                    
                                    // Calculate area
                                    current_area = (k - i + 1) * (l - j + 1);
                                    
                                    // Update max_area if Monge and larger
                                    if (is_monge && current_area > max_area_next) begin
                                        max_area_next = current_area;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    max_area <= max_area_next;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule