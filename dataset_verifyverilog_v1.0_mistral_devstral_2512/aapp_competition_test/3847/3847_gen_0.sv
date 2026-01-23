module find_max_area(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    input [31:0] x,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] INIT      = 4'd1;
    localparam [3:0] PREFIX_A  = 4'd2;
    localparam [3:0] MIN_ROW   = 4'd3;
    localparam [3:0] PREFIX_B  = 4'd4;
    localparam [3:0] MIN_COL   = 4'd5;
    localparam [3:0] MAX_AREA  = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;

    // Internal registers
    reg [7:0] prefix_a [0:7];
    reg [7:0] prefix_b [0:7];
    reg [7:0] min_row [0:7];
    reg [7:0] min_col [0:7];

    reg [3:0] i, j, k;
    reg [7:0] current_sum;
    reg [7:0] min_val;
    reg [15:0] max_area;
    reg [15:0] temp_area;

    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                prefix_a[i] <= 8'd0;
                prefix_b[i] <= 8'd0;
                min_row[i] <= 8'd0;
                min_col[i] <= 8'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            current_sum <= 8'd0;
            min_val <= 8'd0;
            max_area <= 16'd0;
            temp_area <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize prefix arrays
                    prefix_a[0] <= a[0];
                    prefix_b[0] <= b[0];
                    
                    // Initialize min arrays
                    min_row[0] <= a[0];
                    min_col[0] <= b[0];
                    
                    i <= 4'd1;
                    j <= 4'd0;
                    k <= 4'd0;
                    current_sum <= 8'd0;
                    min_val <= 8'd0;
                    max_area <= 16'd0;
                    temp_area <= 16'd0;
                    
                    next_state <= PREFIX_A;
                end

                PREFIX_A: begin
                    // Compute prefix sums for a
                    if (i < n) begin
                        prefix_a[i] <= prefix_a[i-1] + a[i];
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        next_state <= MIN_ROW;
                    end
                end

                MIN_ROW: begin
                    // Compute min_row for each length
                    if (j < n) begin
                        if (i + j < n) begin
                            if (i == 4'd0) begin
                                current_sum <= prefix_a[j];
                                min_val <= prefix_a[j];
                            end else begin
                                current_sum <= prefix_a[i+j] - prefix_a[i-1];
                                if (current_sum < min_val) begin
                                    min_val <= current_sum;
                                end
                            end
                            
                            if (i + j + 1 < n) begin
                                i <= i + 4'd1;
                            end else begin
                                min_row[j] <= min_val;
                                i <= 4'd0;
                                j <= j + 4'd1;
                            end
                        end else begin
                            min_row[j] <= min_val;
                            i <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        i <= 4'd1;
                        j <= 4'd0;
                        next_state <= PREFIX_B;
                    end
                end

                PREFIX_B: begin
                    // Compute prefix sums for b
                    if (i < m) begin
                        prefix_b[i] <= prefix_b[i-1] + b[i];
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        next_state <= MIN_COL;
                    end
                end

                MIN_COL: begin
                    // Compute min_col for each length
                    if (j < m) begin
                        if (i + j < m) begin
                            if (i == 4'd0) begin
                                current_sum <= prefix_b[j];
                                min_val <= prefix_b[j];
                            end else begin
                                current_sum <= prefix_b[i+j] - prefix_b[i-1];
                                if (current_sum < min_val) begin
                                    min_val <= current_sum;
                                end
                            end
                            
                            if (i + j + 1 < m) begin
                                i <= i + 4'd1;
                            end else begin
                                min_col[j] <= min_val;
                                i <= 4'd0;
                                j <= j + 4'd1;
                            end
                        end else begin
                            min_col[j] <= min_val;
                            i <= 4'd0;
                            j <= j + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= MAX_AREA;
                    end
                end

                MAX_AREA: begin
                    // Find maximum area where min_row[i] * min_col[j] <= x
                    if (i < n) begin
                        if (j < m) begin
                            if (min_row[i] * min_col[j] <= x) begin
                                temp_area <= (i + 4'd1) * (j + 4'd1);
                                if (temp_area > max_area) begin
                                    max_area <= temp_area;
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        result <= max_area;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end
    end

endmodule