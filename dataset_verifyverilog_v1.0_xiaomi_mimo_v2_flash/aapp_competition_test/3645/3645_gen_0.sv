module guess_circle (
    input wire [7:0] n,
    input wire [7:0] values [0:15],
    output reg [7:0] result [0:15],
    output reg [3:0] count
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] BUILD_UNIQUE    = 3'd1;
    localparam [2:0] CHECK_GOOD      = 3'd2;
    localparam [2:0] CHECK_OTHER     = 3'd3;
    localparam [2:0] CHECK_Y         = 3'd4;
    localparam [2:0] SORT_RESULT     = 3'd5;
    localparam [2:0] FINISH          = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] unique_vals [0:15];
    reg [3:0] unique_count;
    reg [3:0] current_idx;
    reg [7:0] current_val;
    reg [3:0] other_idx;
    reg [7:0] other_val;
    reg [3:0] y_idx;
    reg [7:0] y_val;
    reg good_flag;
    reg other_good_flag;
    reg y_good_flag;
    reg [7:0] final_results [0:15];
    reg [3:0] final_count;
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [7:0] temp_val;

    // Helper signals
    integer i, j, k;
    reg [3:0] dist;
    reg [7:0] sum_val;
    reg found_in_cw;
    reg found_in_ccw;
    reg all_y_ok;

    // Helper function to compute intersection type
    // Returns 1 if pos is in CwInt(val), 2 if in CcwInt(val), 3 if both, 0 if neither
    function automatic [1:0] get_intersection_type;
        input [7:0] val;
        input [3:0] pos;
        input [7:0] all_values [0:15];
        input [3:0] num_n;

        reg cw_ok, ccw_ok;
        reg [3:0] occ_pos;
        reg [3:0] d;
        begin
            cw_ok = 1'b1;
            ccw_ok = 1'b1;

            // Check all positions in circle
            for (occ_pos = 0; occ_pos < num_n; occ_pos = occ_pos + 1) begin
                if (all_values[occ_pos] == val) begin
                    // Clockwise distance from occ_pos to pos
                    if (pos >= occ_pos) begin
                        d = pos - occ_pos;
                    end else begin
                        d = num_n - occ_pos + pos;
                    end
                    // If dist >= n/2, not in CwInt
                    if (d >= (num_n >> 1)) begin // assuming n/2, if n odd, floor(n/2)
                        cw_ok = 1'b0;
                    end

                    // Counterclockwise distance from occ_pos to pos
                    if (occ_pos >= pos) begin
                        d = occ_pos - pos;
                    end else begin
                        d = num_n - pos + occ_pos;
                    end
                    // If dist >= n/2, not in CcwInt
                    if (d >= (num_n >> 1)) begin
                        ccw_ok = 1'b0;
                    end
                end
            end

            if (cw_ok && ccw_ok) get_intersection_type = 2'b11;
            else if (cw_ok) get_intersection_type = 2'b01;
            else if (ccw_ok) get_intersection_type = 2'b10;
            else get_intersection_type = 2'b00;
        end
    endfunction

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (n > 8'd0) next_state = BUILD_UNIQUE;
                else next_state = FINISH;
            end
            BUILD_UNIQUE: begin
                if (current_idx >= n) next_state = CHECK_GOOD;
            end
            CHECK_GOOD: begin
                if (current_idx >= unique_count) next_state = SORT_RESULT;
                else next_state = CHECK_OTHER;
            end
            CHECK_OTHER: begin
                if (other_idx >= unique_count) begin
                    // Done checking others for current_val
                    if (good_flag) begin
                        // Add to result (we will do in combinational part or next state)
                        next_state = CHECK_GOOD;
                    end else begin
                        next_state = CHECK_GOOD;
                    end
                end else if (other_val == current_val) begin
                    next_state = CHECK_OTHER; // Skip self
                end else begin
                    next_state = CHECK_Y;
                end
            end
            CHECK_Y: begin
                if (y_idx >= n) begin
                    if (!other_good_flag) begin
                        // y not found, so condition fails for this other
                        next_state = CHECK_OTHER;
                    end else begin
                        next_state = CHECK_OTHER;
                    end
                end else begin
                    // Logic handled in state body to decide next
                end
            end
            SORT_RESULT: begin
                if (sort_i >= final_count - 1) next_state = FINISH;
            end
            FINISH: next_state = FINISH;
            default: next_state = IDLE;
        endcase
    end

    // State Machine Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            unique_count <= 4'd0;
            current_idx <= 4'd0;
            other_idx <= 4'd0;
            y_idx <= 4'd0;
            good_flag <= 1'b1;
            other_good_flag <= 1'b0;
            y_good_flag <= 1'b0;
            final_count <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                final_results[i] <= 8'd0;
                unique_vals[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    // Reset intermediate variables
                    unique_count <= 4'd0;
                    current_idx <= 4'd0;
                    good_flag <= 1'b1;
                    final_count <= 4'd0;
                    sort_i <= 4'd0;
                end

                BUILD_UNIQUE: begin
                    // Filter unique values from input array (first n elements)
                    if (current_idx < n) begin
                        // Check if values[current_idx] is already in unique_vals
                        reg found;
                        found = 1'b0;
                        for (k = 0; k < unique_count; k = k + 1) begin
                            if (unique_vals[k] == values[current_idx]) begin
                                found = 1'b1;
                            end
                        end
                        if (!found) begin
                            unique_vals[unique_count] <= values[current_idx];
                            unique_count <= unique_count + 4'd1;
                        end
                        current_idx <= current_idx + 4'd1;
                    end
                end

                CHECK_GOOD: begin
                    if (current_idx < unique_count) begin
                        current_val <= unique_vals[current_idx];
                        other_idx <= 4'd0;
                        good_flag <= 1'b1;
                        other_good_flag <= 1'b0;
                        y_idx <= 4'd0;
                    end
                end

                CHECK_OTHER: begin
                    if (other_idx < unique_count) begin
                        if (unique_vals[other_idx] == current_val) begin
                            other_idx <= other_idx + 4'd1;
                            y_idx <= 4'd0;
                            other_good_flag <= 1'b0;
                        end else begin
                            other_val <= unique_vals[other_idx];
                            y_idx <= 4'd0;
                            other_good_flag <= 1'b0;
                        end
                    end else begin
                        // Finished checking all others
                        if (good_flag) begin
                            // Add current_val to final_results
                            if (final_count < 16) begin
                                final_results[final_count] <= current_val;
                                final_count <= final_count + 4'd1;
                            end
                        end
                        current_idx <= current_idx + 4'd1;
                    end
                end

                CHECK_Y: begin
                    if (y_idx < n) begin
                        y_val <= values[y_idx];
                        // Check if y_val is distinct from current and other
                        if (y_val != current_val && y_val != other_val) begin
                            // Check intersections
                            reg [1:0] type_cur;
                            reg [1:0] type_oth;
                            // Combinational function call is not standard in always block for synthesis in some tools
                            // We implement logic manually here to be safe
                            
                            // Check CwInt(current) and CcwInt(other)
                            reg cw_cur, ccw_cur, cw_oth, ccw_oth;
                            reg [3:0] d;
                            cw_cur = 1'b1; ccw_cur = 1'b1;
                            cw_oth = 1'b1; ccw_oth = 1'b1;
                            for (k = 0; k < n; k = k + 1) begin
                                if (values[k] == current_val) begin
                                    if (y_idx >= k) d = y_idx - k; else d = n - k + y_idx;
                                    if (d >= (n >> 1)) cw_cur = 1'b0;
                                    if (k >= y_idx) d = k - y_idx; else d = n - y_idx + k;
                                    if (d >= (n >> 1)) ccw_cur = 1'b0;
                                end
                                if (values[k] == other_val) begin
                                    if (y_idx >= k) d = y_idx - k; else d = n - k + y_idx;
                                    if (d >= (n >> 1)) cw_oth = 1'b0;
                                    if (k >= y_idx) d = k - y_idx; else d = n - y_idx + k;
                                    if (d >= (n >> 1)) ccw_oth = 1'b0;
                                end
                            end
                            
                            reg ok1, ok2;
                            ok1 = (cw_cur && ccw_oth);
                            ok2 = (ccw_cur && cw_oth);
                            
                            if (ok1 || ok2) begin
                                other_good_flag <= 1'b1;
                                y_idx <= n; // Break loop
                            end else begin
                                y_idx <= y_idx + 4'd1;
                            end
                        end else begin
                            y_idx <= y_idx + 4'd1;
                        end
                    end else begin
                        if (!other_good_flag) begin
                            good_flag <= 1'b0;
                        end
                        other_idx <= other_idx + 4'd1;
                    end
                end

                SORT_RESULT: begin
                    // Bubble sort
                    if (sort_i < final_count - 1) begin
                        if (sort_j < final_count - 1 - sort_i) begin
                            if (final_results[sort_j] > final_results[sort_j + 1]) begin
                                temp_val <= final_results[sort_j];
                                final_results[sort_j] <= final_results[sort_j + 1];
                                final_results[sort_j + 1] <= temp_val;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end
                end

                FINISH: begin
                    // Copy to output
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] <= final_results[i];
                    end
                    count <= final_count;
                end
            endcase
        end
    end

endmodule