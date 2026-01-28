module set_difference(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:15],
    input [7:0] arr2 [0:15],
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result [0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i_reg, j_reg;
    reg [3:0] write_ptr;
    reg match_found;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            write_ptr <= 4'd0;
            match_found <= 1'b0;
            len_out <= 4'd0;
            done <= 1'b0;
            // Initialize result array
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                result[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COMPARE;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        write_ptr <= 4'd0;
                        len_out <= 4'd0;
                        match_found <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPARE: begin
                    // Check if we've processed all elements in arr1
                    if (i_reg >= len1) begin
                        next_state <= COMPLETE;
                    end else begin
                        // Check if current element matches any in arr2
                        if (j_reg < len2) begin
                            if (arr1[i_reg] == arr2[j_reg]) begin
                                match_found <= 1'b1;
                            end
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            // Finished checking arr2 for this element
                            if (!match_found) begin
                                // No match found, add to result
                                result[write_ptr] <= arr1[i_reg];
                                write_ptr <= write_ptr + 4'd1;
                            end
                            match_found <= 1'b0;
                            j_reg <= 4'd0;
                            i_reg <= i_reg + 4'd1;
                        end
                    end
                end

                COMPLETE: begin
                    len_out <= write_ptr;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule