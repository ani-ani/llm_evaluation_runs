module ArrayCommonElementChecker(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    input [3:0] len1,
    input [3:0] len2,
    output reg result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] OUTER_LOOP = 4'd1;
    localparam [3:0] INNER_LOOP = 4'd2;
    localparam [3:0] MATCH     = 4'd3;
    localparam [3:0] NO_MATCH  = 4'd4;
    localparam [3:0] DONE      = 4'd5;

    // Counters and registers
    reg [3:0] state;
    reg [3:0] outer_idx;
    reg [3:0] inner_idx;
    reg [7:0] current_arr1;
    reg [7:0] current_arr2;
    reg match_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            outer_idx <= 4'd0;
            inner_idx <= 4'd0;
            current_arr1 <= 8'd0;
            current_arr2 <= 8'd0;
            match_found <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    match_found <= 1'b0;
                    if (start) begin
                        if (len1 == 4'd0 || len2 == 4'd0) begin
                            state <= NO_MATCH;
                        end else begin
                            state <= OUTER_LOOP;
                            outer_idx <= 4'd0;
                        end
                    end
                end

                OUTER_LOOP: begin
                    current_arr1 <= arr1[outer_idx];
                    inner_idx <= 4'd0;
                    state <= INNER_LOOP;
                end

                INNER_LOOP: begin
                    current_arr2 <= arr2[inner_idx];
                    if (current_arr1 == current_arr2) begin
                        match_found <= 1'b1;
                        state <= MATCH;
                    end else begin
                        if (inner_idx == len2 - 4'd1) begin
                            if (outer_idx == len1 - 4'd1) begin
                                state <= NO_MATCH;
                            end else begin
                                outer_idx <= outer_idx + 4'd1;
                                state <= OUTER_LOOP;
                            end
                        end else begin
                            inner_idx <= inner_idx + 4'd1;
                        end
                    end
                end

                MATCH: begin
                    result <= 1'b1;
                    state <= DONE;
                end

                NO_MATCH: begin
                    result <= 1'b0;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule