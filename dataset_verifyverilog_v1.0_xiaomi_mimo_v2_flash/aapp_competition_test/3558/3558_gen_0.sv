module tv_coverage (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [15:0] D,
    input [7:0] transmitter_flags,
    input [15:0] X [0:7],
    input [15:0] H [0:7],
    output real covered_length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMP = 2'd1;
    localparam [1:0] MERGE = 2'd2;
    localparam [1:0] COMPUTE_COVERAGE = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Control registers
    reg [3:0] i, j, k;
    reg [3:0] cnt;
    
    // Data storage
    reg [15:0] left_bounds [0:7];
    reg [15:0] right_bounds [0:7];
    reg valid [0:7];
    reg [15:0] intervals_left [0:7];
    reg [15:0] intervals_right [0:7];
    
    // Computation registers
    reg [15:0] current_left;
    reg [15:0] current_right;
    reg [31:0] total_length;
    
    // Temporary registers for swap
    reg [15:0] temp_left;
    reg [15:0] temp_right;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMP;
                else next_state = IDLE;
            end
            COMP: begin
                if (i >= N) next_state = MERGE;
                else next_state = COMP;
            end
            MERGE: begin
                if (cnt == 4'd0) next_state = IDLE;
                else if (k >= cnt - 4'd1) next_state = COMPUTE_COVERAGE;
                else next_state = MERGE;
            end
            COMPUTE_COVERAGE: begin
                if (k >= cnt) next_state = IDLE;
                else next_state = COMPUTE_COVERAGE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            covered_length <= 0.0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            cnt <= 4'd0;
            cycle_count <= 16'd0;
            current_left <= 16'd0;
            current_right <= 16'd0;
            total_length <= 32'd0;
            temp_left <= 16'd0;
            temp_right <= 16'd0;
            
            // Initialize arrays
            begin : init_arrays
                integer idx;
                for (idx = 0; idx < 8; idx = idx + 1) begin
                    left_bounds[idx] <= 16'd0;
                    right_bounds[idx] <= 16'd0;
                    valid[idx] <= 1'b0;
                    intervals_left[idx] <= 16'd0;
                    intervals_right[idx] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            if (start) begin
                cycle_count <= 16'd0;
            end else begin
                cycle_count <= cycle_count + 16'd1;
            end
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset all registers for new computation
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        cnt <= 4'd0;
                        covered_length <= 0.0;
                        total_length <= 32'd0;
                        current_left <= 16'd0;
                        current_right <= 16'd0;
                        
                        // Initialize valid flags
                        begin : reset_valid
                            integer idx;
                            for (idx = 0; idx < 8; idx = idx + 1) begin
                                valid[idx] <= 1'b0;
                            end
                        end
                    end
                end
                
                COMP: begin
                    if (i < N && i < 8) begin
                        if (transmitter_flags[i]) begin
                            if (j < N && j < 8) begin
                                if (j == i) begin
                                    j <= j + 4'd1;
                                end else begin
                                    // Calculate intersection
                                    if (X[j] < X[i]) begin
                                        // Left intersection
                                        // limit = x_j - (h_j/h_t)*(x_t-x_j)
                                        // In fixed-point: (x_t - x_j) * h_j / h_t
                                        if (H[i] != 16'd0) begin
                                            reg [31:0] diff;
                                            reg [47:0] temp;
                                            reg [15:0] limit;
                                            
                                            diff = X[i] - X[j];
                                            temp = diff * H[j];
                                            limit = temp / H[i];
                                            limit = X[j] - limit;
                                            
                                            if (j == 4'd0 || !valid[i]) begin
                                                left_bounds[i] <= limit;
                                                valid[i] <= 1'b1;
                                            end else if (limit > left_bounds[i]) begin
                                                left_bounds[i] <= limit;
                                            end
                                        end
                                    end else if (X[j] > X[i]) begin
                                        // Right intersection
                                        if (H[i] != 16'd0) begin
                                            reg [31:0] diff;
                                            reg [47:0] temp;
                                            reg [15:0] limit;
                                            
                                            diff = X[j] - X[i];
                                            temp = diff * H[j];
                                            limit = temp / H[i];
                                            limit = X[j] + limit;
                                            
                                            if (j == 4'd0 || !valid[i]) begin
                                                right_bounds[i] <= limit;
                                                valid[i] <= 1'b1;
                                            end else if (limit < right_bounds[i]) begin
                                                right_bounds[i] <= limit;
                                            end
                                        end
                                    end
                                    j <= j + 4'd1;
                                end
                            end else begin
                                // Finished with this transmitter
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            // Transmitter not active, skip
                            i <= i + 4'd1;
                        end
                    end
                end
                
                MERGE: begin
                    if (cnt == 4'd0) begin
                        // Build interval list
                        cnt <= 4'd0;
                        begin : build_intervals
                            integer idx;
                            for (idx = 0; idx < 8; idx = idx + 1) begin
                                if (valid[idx]) begin
                                    intervals_left[cnt] <= left_bounds[idx];
                                    intervals_right[cnt] <= right_bounds[idx];
                                    cnt <= cnt + 4'd1;
                                end
                            end
                        end
                        k <= 4'd0;
                    end else if (k < cnt - 4'd1) begin
                        // Bubble sort to merge overlapping intervals
                        if (intervals_left[k] > intervals_left[k+1]) begin
                            temp_left <= intervals_left[k];
                            temp_right <= intervals_right[k];
                            intervals_left[k] <= intervals_left[k+1];
                            intervals_right[k] <= intervals_right[k+1];
                            intervals_left[k+1] <= temp_left;
                            intervals_right[k+1] <= temp_right;
                        end
                        k <= k + 4'd1;
                    end
                end
                
                COMPUTE_COVERAGE: begin
                    if (k == 4'd0) begin
                        // Initialize with first interval
                        current_left <= intervals_left[0];
                        current_right <= intervals_right[0];
                        k <= 4'd1;
                    end else if (k < cnt) begin
                        // Check if intervals overlap
                        if (intervals_left[k] <= current_right) begin
                            // Overlapping - extend current interval
                            if (intervals_right[k] > current_right) begin
                                current_right <= intervals_right[k];
                            end
                        end else begin
                            // Non-overlapping - add previous interval length
                            total_length <= total_length + (current_right - current_left);
                            current_left <= intervals_left[k];
                            current_right <= intervals_right[k];
                        end
                        k <= k + 4'd1;
                    end else begin
                        // Add final interval
                        total_length <= total_length + (current_right - current_left);
                        covered_length <= total_length;
                        done <= 1'b1;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                covered_length <= 0.0;
            end
        end
    end
endmodule