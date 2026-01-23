module file_deletion (
    input clk,
    input rst_n,
    input start,
    input [13:0] nr, nc,
    input [2:0] N,
    input [231:0] points_packed,
    output reg [3:0] moves,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] ITERATE = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] FINISH  = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] count;
    reg [3:0] max_f;
    reg [3:0] current_f;
    reg [3:0] n_delete;
    reg [3:0] x_left_idx, x_right_idx;
    reg [3:0] y_low_idx, y_high_idx;
    reg [3:0] i, j;
    reg [2:0] sort_i, sort_j;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12; // Conservative limit

    // Storage for points
    reg [13:0] x_coords [0:7];
    reg [13:0] y_coords [0:7];
    reg types [0:7];

    // Compressed coordinates
    reg [13:0] xs [0:9];
    reg [13:0] ys [0:9];
    reg [3:0] xs_count;
    reg [3:0] ys_count;

    // Temp registers for sorting
    reg [13:0] temp_val;
    reg [3:0] temp_idx;

    // Extract bits from packed points
    wire [28:0] point_wire [0:7];
    assign point_wire[0] = points_packed[28:0];
    assign point_wire[1] = points_packed[57:29];
    assign point_wire[2] = points_packed[86:58];
    assign point_wire[3] = points_packed[115:87];
    assign point_wire[4] = points_packed[144:116];
    assign point_wire[5] = points_packed[173:145];
    assign point_wire[6] = points_packed[202:174];
    assign point_wire[7] = points_packed[231:203];

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
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = SORT;
            end
            SORT: begin
                // Sort xs array (bubble sort)
                if (sort_i < xs_count) begin
                    next_state = SORT;
                end else if (sort_j < ys_count) begin
                    next_state = SORT;
                end else begin
                    next_state = ITERATE;
                end
            end
            ITERATE: begin
                next_state = ITERATE;
                if (x_left_idx >= xs_count - 1) begin
                    next_state = FINISH;
                end
            end
            COMPUTE: begin
                if (i >= N) begin
                    if (current_f > max_f) next_state = ITERATE;
                    else next_state = ITERATE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all regs
            moves <= 4'd0;
            done <= 1'b0;
            max_f <= 4'd0;
            current_f <= 4'd0;
            n_delete <= 4'd0;
            count <= 4'd0;
            xs_count <= 4'd0;
            ys_count <= 4'd0;
            x_left_idx <= 4'd0;
            x_right_idx <= 4'd0;
            y_low_idx <= 4'd0;
            y_high_idx <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            cycle_count <= 4'd0;
            // Initialize arrays
            for (integer k = 0; k < 8; k = k + 1) begin
                x_coords[k] <= 14'd0;
                y_coords[k] <= 14'd0;
                types[k] <= 1'b0;
            end
            for (integer k = 0; k < 10; k = k + 1) begin
                xs[k] <= 14'd0;
                ys[k] <= 14'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        max_f <= 4'd0;
                        current_f <= 4'd0;
                        n_delete <= 4'd0;
                        count <= 4'd0;
                        xs_count <= 4'd0;
                        ys_count <= 4'd0;
                        x_left_idx <= 4'd0;
                        x_right_idx <= 4'd0;
                        y_low_idx <= 4'd0;
                        y_high_idx <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        cycle_count <= 4'd0;
                    end
                end

                LOAD: begin
                    // Unpack points
                    for (integer idx = 0; idx < 8; idx = idx + 1) begin
                        if (idx < N) begin
                            types[idx] <= point_wire[idx][28];
                            x_coords[idx] <= point_wire[idx][27:14];
                            y_coords[idx] <= point_wire[idx][13:0];
                            if (point_wire[idx][28]) n_delete <= n_delete + 1;
                        end
                    end
                    // Add boundaries
                    xs[0] <= 14'd0;
                    xs[1] <= nr;
                    ys[0] <= 14'd0;
                    ys[1] <= nc;
                    xs_count <= 4'd2;
                    ys_count <= 4'd2;
                end

                SORT: begin
                    // Insert points into xs/ys arrays and sort
                    if (sort_j < N) begin
                        // Add to xs if unique and not boundary
                        if (sort_i < N) begin
                            reg [13:0] val = x_coords[sort_i];
                            reg is_unique = 1'b1;
                            reg is_boundary = (val == 14'd0) || (val == nr);
                            if (!is_boundary) begin
                                for (integer k = 0; k < xs_count; k = k + 1) begin
                                    if (xs[k] == val) is_unique = 1'b0;
                                end
                                if (is_unique && xs_count < 10) begin
                                    xs[xs_count] <= val;
                                    xs_count <= xs_count + 1;
                                end
                            end
                            sort_i <= sort_i + 1;
                        end else begin
                            // Add to ys if unique and not boundary
                            reg [13:0] val = y_coords[sort_j];
                            reg is_unique = 1'b1;
                            reg is_boundary = (val == 14'd0) || (val == nc);
                            if (!is_boundary) begin
                                for (integer k = 0; k < ys_count; k = k + 1) begin
                                    if (ys[k] == val) is_unique = 1'b0;
                                end
                                if (is_unique && ys_count < 10) begin
                                    ys[ys_count] <= val;
                                    ys_count <= ys_count + 1;
                                end
                            end
                            sort_j <= sort_j + 1;
                            sort_i <= 4'd0;
                        end
                    end else if (sort_i < xs_count) begin
                        // Bubble sort xs
                        if (sort_i < xs_count - 1) begin
                            if (xs[sort_i] > xs[sort_i + 1]) begin
                                temp_val <= xs[sort_i];
                                xs[sort_i] <= xs[sort_i + 1];
                                xs[sort_i + 1] <= temp_val;
                            end
                            sort_i <= sort_i + 1;
                        end else begin
                            sort_i <= 4'd0;
                            sort_j <= 4'd0;
                        end
                    end else if (sort_j < ys_count) begin
                        // Bubble sort ys
                        if (sort_j < ys_count - 1) begin
                            if (ys[sort_j] > ys[sort_j + 1]) begin
                                temp_val <= ys[sort_j];
                                ys[sort_j] <= ys[sort_j + 1];
                                ys[sort_j + 1] <= temp_val;
                            end
                            sort_j <= sort_j + 1;
                        end
                    end
                end

                ITERATE: begin
                    // Reset for new rectangle iteration
                    if (x_left_idx < xs_count - 1) begin
                        if (x_right_idx < xs_count) begin
                            if (y_low_idx < ys_count - 1) begin
                                if (y_high_idx < ys_count) begin
                                    current_f <= 4'd0;
                                    i <= 4'd0;
                                    cycle_count <= 4'd0;
                                end else begin
                                    y_low_idx <= y_low_idx + 1;
                                    y_high_idx <= y_low_idx + 2;
                                end
                            end else begin
                                y_low_idx <= 4'd1;
                                y_high_idx <= 4'd2;
                                x_right_idx <= x_right_idx + 1;
                            end
                        end else begin
                            x_left_idx <= x_left_idx + 1;
                            x_right_idx <= x_left_idx + 2;
                            y_low_idx <= 4'd1;
                            y_high_idx <= 4'd2;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 1;
                    if (i < N) begin
                        // Check if point inside rectangle
                        reg [13:0] px = x_coords[i];
                        reg [13:0] py = y_coords[i];
                        if (px >= xs[x_left_idx] && px <= xs[x_right_idx] &&
                            py >= ys[y_low_idx] && py <= ys[y_high_idx]) begin
                            if (types[i]) current_f <= current_f + 1;
                            else current_f <= current_f - 1;
                        end
                        i <= i + 1;
                    end else begin
                        if (current_f > max_f) max_f <= current_f;
                    end
                    // Timeout or completion
                    if (i >= N || cycle_count >= MAX_CYCLES) begin
                        if (current_f > max_f) max_f <= current_f;
                    end
                end

                FINISH: begin
                    moves <= n_delete - max_f;
                    done <= 1'b1;
                    x_left_idx <= 4'd0;
                    x_right_idx <= 4'd0;
                    y_low_idx <= 4'd0;
                    y_high_idx <= 4'd0;
                    i <= 4'd0;
                end
            endcase
        end
    end
endmodule