module stick_removal_order (
    input              clk,
    input              rst_n,
    input              start,
    input       [3:0]  N,
    input      [13:0]  x1_0, y1_0, x2_0, y2_0,
    input      [13:0]  x1_1, y1_1, x2_1, y2_1,
    input      [13:0]  x1_2, y1_2, x2_2, y2_2,
    input      [13:0]  x1_3, y1_3, x2_3, y2_3,
    input      [13:0]  x1_4, y1_4, x2_4, y2_4,
    input      [13:0]  x1_5, y1_5, x2_5, y2_5,
    input      [13:0]  x1_6, y1_6, x2_6, y2_6,
    input      [13:0]  x1_7, y1_7, x2_7, y2_7,
    output reg  [3:0]  data_out,
    output reg         valid_out,
    output reg         done
);

// Stick coordinate storage
reg [13:0] x1 [0:7];
reg [13:0] y1 [0:7];
reg [13:0] x2 [0:7];
reg [13:0] y2 [0:7];

// FSM states
localparam [1:0] IDLE        = 2'd0;
localparam [1:0] COMPUTE_DEPS= 2'd1;
localparam [1:0] OUTPUT      = 2'd2;
reg [1:0] state, next_state;

// COMPUTE_DEPS counters
reg [3:0] i, j;

// Dependency and degree tracking
reg [7:0] dep [0:7];       // dep[i] has bits set for dependencies
reg [7:0] succ [0:7];      // succ[j] has bits set for successors
reg [3:0] indegree [0:7];  // Current indegree for each stick
reg [7:0] removed;         // Bits set when stick removed

// Output phase counter
reg [3:0] output_cnt;

// Loop indices
integer idx;

// FSM Update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid_out <= 1'b0;
        data_out <= 4'd0;
        removed <= 8'd0;
        output_cnt <= 4'd0;
        
        // Clear dependency arrays
        for (idx = 0; idx < 8; idx = idx + 1) begin
            dep[idx] <= 8'd0;
            succ[idx] <= 8'd0;
            indegree[idx] <= 4'd0;
            x1[idx] <= 14'd0;
            y1[idx] <= 14'd0;
            x2[idx] <= 14'd0;
            y2[idx] <= 14'd0;
        end
    end else begin
        done <= 1'b0;
        valid_out <= 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Latch inputs
                    x1[0] <= x1_0; y1[0] <= y1_0; x2[0] <= x2_0; y2[0] <= y2_0;
                    x1[1] <= x1_1; y1[1] <= y1_1; x2[1] <= x2_1; y2[1] <= y2_1;
                    x1[2] <= x1_2; y1[2] <= y1_2; x2[2] <= x2_2; y2[2] <= y2_2;
                    x1[3] <= x1_3; y1[3] <= y1_3; x2[3] <= x2_3; y2[3] <= y2_3;
                    x1[4] <= x1_4; y1[4] <= y1_4; x2[4] <= x2_4; y2[4] <= y2_4;
                    x1[5] <= x1_5; y1[5] <= y1_5; x2[5] <= x2_5; y2[5] <= y2_5;
                    x1[6] <= x1_6; y1[6] <= y1_6; x2[6] <= x2_6; y2[6] <= y2_6;
                    x1[7] <= x1_7; y1[7] <= y1_7; x2[7] <= x2_7; y2[7] <= y2_7;
                    state <= COMPUTE_DEPS;
                    i <= 4'd0;
                    j <= 4'd0;
                end
            end

            COMPUTE_DEPS: begin
                // Check i and j in range [0,N-1]
                if (i < N) begin
                    if (j < N) begin
                        if (i != j) begin
                            // Compute x overlap
                            // Stick i coordinates
                            wire [13:0] x1_i = x1[i];
                            wire [13:0] x2_i = x2[i];
                            wire [14:0] min_x_i = (x1_i < x2_i) ? x1_i : x2_i;
                            wire [14:0] max_x_i = (x1_i > x2_i) ? x1_i : x2_i;
                            
                            // Stick j coordinates
                            wire [13:0] x1_j = x1[j];
                            wire [13:0] x2_j = x2[j];
                            wire [14:0] min_x_j = (x1_j < x2_j) ? x1_j : x2_j;
                            wire [14:0] max_x_j = (x1_j > x2_j) ? x1_j : x2_j;
                            
                            // Check overlap:
                            if ((min_x_i <= max_x_j) && (min_x_j <= max_x_i)) begin
                                wire [14:0] min_overlap = (min_x_i > min_x_j) ? min_x_i : min_x_j;
                                wire [14:0] max_overlap = (max_x_i < max_x_j) ? max_x_i : max_x_j;
                                
                                // Compute y for i and j at both ends (64-bit intermediates)
                                // For stick i: y = ((y2_i - y1_i)*(x - x1_i))/(x2_i - x1_i) + y1_i
                                wire signed [63:0] dx_i = (x2_i - x1_i);
                                wire signed [63:0] dy_i = (y2[i] - y1[i]);
                                
                                wire signed [63:0] y_i_min = (dy_i * (min_overlap - x1_i)) / (dx_i) + y1[i];
                                wire signed [63:0] y_i_max = (dy_i * (max_overlap - x1_i)) / (dx_i) + y1[i];
                                
                                // For stick j
                                wire signed [63:0] dx_j = (x2_j - x1_j);
                                wire signed [63:0] dy_j = (y2[j] - y1[j]);
                                
                                wire signed [63:0] y_j_min = (dy_j * (min_overlap - x1_j)) / (dx_j) + y1[j];
                                wire signed [63:0] y_j_max = (dy_j * (max_overlap - x1_j)) / (dx_j) + y1[j];
                                
                                // Check if j is below i at both points
                                if (y_j_min < y_i_min && y_j_max < y_i_max) begin
                                    dep[i][j] <= 1'b1;  // i depends on j
                                    succ[j][i] <= 1'b1; // j has successor i
                                    indegree[i] <= indegree[i] + 4'd1;
                                end
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end else begin
                    state <= OUTPUT;
                    output_cnt <= 4'd0;
                end
            end

            OUTPUT: begin
                if (output_cnt < N) begin
                    // Find a node with indegree 0 not removed
                    if (!removed[0] && indegree[0] == 4'd0) begin
                        data_out <= 4'd0;
                        valid_out <= 1'b1;
                        removed[0] <= 1'b1;
                        // Decrement indegrees of successors
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[0][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[1] && indegree[1] == 4'd0) begin
                        data_out <= 4'd1;
                        valid_out <= 1'b1;
                        removed[1] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[1][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[2] && indegree[2] == 4'd0) begin
                        data_out <= 4'd2;
                        valid_out <= 1'b1;
                        removed[2] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[2][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[3] && indegree[3] == 4'd0) begin
                        data_out <= 4'd3;
                        valid_out <= 1'b1;
                        removed[3] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[3][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[4] && indegree[4] == 4'd0) begin
                        data_out <= 4'd4;
                        valid_out <= 1'b1;
                        removed[4] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[4][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[5] && indegree[5] == 4'd0) begin
                        data_out <= 4'd5;
                        valid_out <= 1'b1;
                        removed[5] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[5][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[6] && indegree[6] == 4'd0) begin
                        data_out <= 4'd6;
                        valid_out <= 1'b1;
                        removed[6] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[6][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end else if (!removed[7] && indegree[7] == 4'd0) begin
                        data_out <= 4'd7;
                        valid_out <= 1'b1;
                        removed[7] <= 1'b1;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (succ[7][idx]) begin
                                indegree[idx] <= indegree[idx] - 4'd1;
                            end
                        end
                        output_cnt <= output_cnt + 4'd1;
                    end
                end else begin
                    // All outputs done
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule