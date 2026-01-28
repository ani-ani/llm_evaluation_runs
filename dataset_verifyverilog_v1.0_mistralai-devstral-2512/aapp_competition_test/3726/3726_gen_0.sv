module card_flip_operations(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] group_parity,
    input wire [4:0] num_groups,
    input wire [15:0] adj_matrix [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COUNT     = 3'd1;
    localparam [2:0] MATCHING  = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd5000;

    // Count registers
    reg [4:0] e_count;
    reg [4:0] o_count;
    reg [4:0] group_idx;

    // Matching registers
    reg [3:0] match_even [0:15];
    reg [3:0] match_odd [0:15];
    reg [3:0] current_even;
    reg [3:0] current_odd;
    reg [3:0] path_ptr;
    reg [3:0] path [0:15];
    reg [3:0] visited [0:15];
    reg [3:0] f;

    // Intermediate results
    reg [4:0] remaining_even;
    reg [4:0] remaining_odd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            e_count <= 5'd0;
            o_count <= 5'd0;
            group_idx <= 5'd0;
            f <= 4'd0;
            current_even <= 4'd0;
            current_odd <= 4'd0;
            path_ptr <= 4'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                match_even[i] <= 4'd0;
                match_odd[i] <= 4'd0;
                visited[i] <= 4'd0;
                path[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (group_idx < num_groups) begin
                        if (group_parity[group_idx]) begin
                            e_count <= e_count + 5'd1;
                        end else begin
                            o_count <= o_count + 5'd1;
                        end
                        group_idx <= group_idx + 5'd1;
                    end else begin
                        group_idx <= 5'd0;
                        state <= MATCHING;
                    end
                end

                MATCHING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_even < e_count) begin
                        // Initialize visited and path
                        for (integer i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 4'd0;
                            path[i] <= 4'd0;
                        end
                        path_ptr <= 4'd0;
                        current_odd <= 4'd0;
                        state <= MATCHING;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    remaining_even <= e_count - f;
                    remaining_odd <= o_count - f;
                    result <= f + 2'd0 * ((remaining_even >> 1) + (remaining_odd >> 1)) + 3'd0 * (remaining_even & 1'b1);
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Matching logic (simplified for synthesis)
    always @(posedge clk) begin
        if (state == MATCHING && current_even < e_count) begin
            if (current_odd < o_count) begin
                if (adj_matrix[current_even][current_odd] && !visited[current_odd]) begin
                    visited[current_odd] <= 1'b1;
                    path[path_ptr] <= current_odd;
                    path_ptr <= path_ptr + 4'd1;
                    if (match_odd[current_odd] == 4'd0) begin
                        // Found augmenting path
                        match_odd[current_odd] <= current_even + 4'd1;
                        match_even[current_even] <= current_odd + 4'd1;
                        f <= f + 4'd1;
                        current_even <= current_even + 4'd1;
                    end else begin
                        current_even <= match_odd[current_odd] - 4'd1;
                    end
                end else begin
                    current_odd <= current_odd + 4'd1;
                end
            end else begin
                // Backtrack
                if (path_ptr > 4'd0) begin
                    path_ptr <= path_ptr - 4'd1;
                    current_odd <= path[path_ptr] + 4'd1;
                    visited[current_odd] <= 1'b0;
                end else begin
                    current_even <= current_even + 4'd1;
                end
            end
        end
    end

endmodule