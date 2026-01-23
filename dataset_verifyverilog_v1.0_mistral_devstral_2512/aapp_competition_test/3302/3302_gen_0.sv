module color_code_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [3:0] p_mask,
    output reg [3:0] output_value,
    output reg output_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] OUTPUT   = 3'd2;
    localparam [2:0] SEARCH   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] current_value;
    reg [3:0] counter;
    reg [15:0] visited;
    reg [3:0] search_idx;
    reg found_next;
    reg [3:0] next_candidate;

    // Hamming distance function
    function integer hamming;
        input [3:0] a;
        input [3:0] b;
        integer i;
        begin
            hamming = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (a[i] != b[i]) hamming = hamming + 1;
            end
        end
    endfunction

    // Check if distance is allowed
    function integer is_allowed;
        input [3:0] dist;
        input [3:0] mask;
        begin
            if (dist == 0 || dist > 4) begin
                is_allowed = 0;
            end else begin
                is_allowed = mask[dist-1];
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_value <= 4'd0;
            counter <= 4'd0;
            visited <= 16'd0;
            search_idx <= 4'd0;
            found_next <= 1'b0;
            next_candidate <= 4'd0;
            output_value <= 4'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    current_value <= 4'd0;
                    counter <= 4'd0;
                    visited <= 16'd1;  // Mark 0 as visited
                    search_idx <= 4'd0;
                    found_next <= 1'b0;
                    if (n == 2'd0 || n > 2'd2) begin
                        state <= COMPLETE;
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    output_value <= current_value;
                    output_valid <= 1'b1;
                    counter <= counter + 4'd1;
                    if (counter == (1 << n) - 1) begin
                        state <= COMPLETE;
                    end else begin
                        state <= SEARCH;
                        search_idx <= 4'd0;
                        found_next <= 1'b0;
                    end
                end

                SEARCH: begin
                    output_valid <= 1'b0;
                    if (search_idx < (1 << n)) begin
                        if (!visited[search_idx]) begin
                            if (is_allowed(hamming(current_value, search_idx), p_mask)) begin
                                found_next <= 1'b1;
                                next_candidate <= search_idx;
                                visited[search_idx] <= 1'b1;
                                current_value <= search_idx;
                                state <= OUTPUT;
                            end else begin
                                search_idx <= search_idx + 4'd1;
                            end
                        end else begin
                            search_idx <= search_idx + 4'd1;
                        end
                    end else begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    output_valid <= 1'b0;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule