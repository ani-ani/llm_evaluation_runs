module hanabi_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] unique_cards_count,
    input [15:0] card_attributes [0:15],
    output reg [3:0] min_hints,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [9:0] mask;
    reg [3:0] i;
    reg [3:0] j;
    reg processing_done;
    reg [3:0] temp_min;

    // Combinational logic for validity check
    wire is_valid_mask;
    wire [3:0] popcount_val;
    wire [3:0] new_min;

    // Popcount logic
    assign popcount_val = mask[0] + mask[1] + mask[2] + mask[3] + mask[4] +
                         mask[5] + mask[6] + mask[7] + mask[8] + mask[9];

    // Pair check logic: Check all pairs (i, j) within unique_cards_count
    reg is_valid_reg;
    integer p, q;

    always @(*) begin
        is_valid_reg = 1'b1;
        if (unique_cards_count > 1) begin
            for (p = 0; p < 16; p = p + 1) begin
                for (q = p + 1; q < 16; q = q + 1) begin
                    if (p < unique_cards_count && q < unique_cards_count) begin
                        if (((mask & card_attributes[p] & card_attributes[q]) == 10'b0)) begin
                            is_valid_reg = 1'b0;
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_hints <= 4'b1111;
            done <= 1'b0;
            mask <= 10'b0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        mask <= 10'b0;
                        min_hints <= 4'b1111;
                        processing_done <= 1'b0;
                    end
                end

                PROCESSING: begin
                    if (is_valid_reg && (popcount_val < min_hints)) begin
                        min_hints <= popcount_val;
                    end

                    if (mask == 10'h3FF) begin
                        state <= DONE;
                        done <= 1'b1;
                    end else begin
                        mask <= mask + 1'b1;
                    end
                end

                DONE: begin
                    // Hold done high until reset or new start
                end
            endcase
        end
    end

endmodule