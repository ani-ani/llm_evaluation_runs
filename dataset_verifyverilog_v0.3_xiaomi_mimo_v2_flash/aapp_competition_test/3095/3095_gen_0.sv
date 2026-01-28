module MaxCoolSubmatrix #(
    parameter DATA_WIDTH = 12,
    parameter AREA_WIDTH = 6
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] matrix_flat [0:8],
    output reg [AREA_WIDTH-1:0] max_area,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] CHECK_SUB  = 3'd2;
    localparam [2:0] UPDATE_MAX = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Loop counters
    reg [1:0] r1, r2;  // Row range: r1 to r2 (inclusive)
    reg [1:0] c1, c2;  // Column range: c1 to c2 (inclusive)
    reg [1:0] i, j;    // Inner loop indices for Monge check
    
    // Combinational signals
    reg is_monge;
    reg [DATA_WIDTH-1:0] submatrix [0:8];
    reg [1:0] rows, cols;  // Dimensions of current submatrix
    reg [AREA_WIDTH-1:0] current_area;
    reg [AREA_WIDTH-1:0] next_max_area;
    
    // FSM Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = CHECK_SUB;
            end
            CHECK_SUB: begin
                if (is_monge) next_state = UPDATE_MAX;
                else if (r1 == 2'd2 && c2 == 2'd2) next_state = FINISH;
                else next_state = CHECK_SUB;
            end
            UPDATE_MAX: begin
                if (r1 == 2'd2 && c2 == 2'd2) next_state = FINISH;
                else next_state = CHECK_SUB;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational Monge check and area calculation
    always @(*) begin
        // Default values
        is_monge = 1'b1;
        current_area = (rows * cols);
        
        // Extract submatrix
        for (int k = 0; k < 9; k = k + 1) begin
            submatrix[k] = 8'd0;
        end
        
        // Populate submatrix based on ranges
        // Flatten 3x3 matrix: index = row*3 + col
        for (int rr = r1; rr <= r2; rr = rr + 1) begin
            for (int cc = c1; cc <= c2; cc = cc + 1) begin
                submatrix[rr*3 + cc] = matrix_flat[rr*3 + cc];
            end
        end
        
        rows = r2 - r1 + 1'd1;
        cols = c2 - c1 + 1'd1;
        
        // Check Monge condition for submatrices larger than 1x1
        if (rows > 1 && cols > 1) begin
            for (i = r1; i < r2; i = i + 1) begin
                for (j = c1; j < c2; j = j + 1) begin
                    // Check: M[i,j] + M[i+1,j+1] <= M[i,j+1] + M[i+1,j]
                    if (matrix_flat[i*3 + j] + matrix_flat[(i+1)*3 + (j+1)] >
                        matrix_flat[i*3 + (j+1)] + matrix_flat[(i+1)*3 + j]) begin
                        is_monge = 1'b0;
                    end
                end
            end
        end
        
        // Default next max area
        next_max_area = max_area;
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_area <= {AREA_WIDTH{1'b0}};
            done <= 1'b0;
            r1 <= 2'd0;
            r2 <= 2'd0;
            c1 <= 2'd0;
            c2 <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                INIT: begin
                    // Initialize for submatrix iteration
                    r1 <= 2'd0;
                    r2 <= 2'd0;
                    c1 <= 2'd0;
                    c2 <= 2'd0;
                    max_area <= {AREA_WIDTH{1'b0}};
                end
                CHECK_SUB: begin
                    // Check if Monge, update counters if not
                    if (!is_monge) begin
                        // Move to next submatrix
                        if (c2 < 2'd2) begin
                            c2 <= c2 + 2'd1;
                        end else if (r2 < 2'd2) begin
                            c2 <= c1;
                            r2 <= r2 + 2'd1;
                        end else if (c1 < 2'd1) begin
                            c1 <= c1 + 2'd1;
                            c2 <= c1 + 2'd1;
                            r1 <= 2'd0;
                            r2 <= 2'd1;
                        end else if (r1 < 2'd1) begin
                            r1 <= r1 + 2'd1;
                            r2 <= r1 + 2'd1;
                            c1 <= 2'd0;
                            c2 <= 2'd1;
                        end else begin
                            // Should not reach here
                        end
                    end
                end
                UPDATE_MAX: begin
                    // Update max_area and move to next submatrix
                    if (current_area > max_area) begin
                        max_area <= current_area;
                    end
                    
                    // Move to next submatrix
                    if (c2 < 2'd2) begin
                        c2 <= c2 + 2'd1;
                    end else if (r2 < 2'd2) begin
                        c2 <= c1;
                        r2 <= r2 + 2'd1;
                    end else if (c1 < 2'd1) begin
                        c1 <= c1 + 2'd1;
                        c2 <= c1 + 2'd1;
                        r1 <= 2'd0;
                        r2 <= 2'd1;
                    end else if (r1 < 2'd1) begin
                        r1 <= r1 + 2'd1;
                        r2 <= r1 + 2'd1;
                        c1 <= 2'd0;
                        c2 <= 2'd1;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule