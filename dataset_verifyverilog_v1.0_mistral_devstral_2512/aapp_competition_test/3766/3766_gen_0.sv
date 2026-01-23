module hanabi_min_hints (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire [7:0] input_card,
    input wire [4:0] n_in,
    output reg done,
    output reg [3:0] answer
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ       = 3'd1;
    localparam [2:0] INIT_MASK  = 3'd2;
    localparam [2:0] CHECK_MASK = 3'd3;
    localparam [2:0] NEXT_MASK  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] card_index;
    reg [9:0] distinct_cards [0:15];
    reg [9:0] current_mask;
    reg [3:0] min_hints;
    reg [3:0] current_hints;
    reg [3:0] signature_index;
    reg [9:0] signatures [0:15];
    reg [3:0] i, j;
    reg signature_match;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            card_index <= 4'd0;
            current_mask <= 10'd0;
            min_hints <= 4'd10;
            current_hints <= 4'd0;
            signature_index <= 4'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                distinct_cards[i] <= 10'd0;
                signatures[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 4'd0;
                if (start) begin
                    next_state = READ;
                    card_index <= 4'd0;
                end
            end

            READ: begin
                if (input_valid && card_index < n_in) begin
                    distinct_cards[card_index] = {input_card[3:0], input_card[7:4]};
                    card_index <= card_index + 4'd1;
                end
                if (card_index == n_in) begin
                    next_state = INIT_MASK;
                    current_mask <= 10'd0;
                    min_hints <= 4'd10;
                end
            end

            INIT_MASK: begin
                next_state = CHECK_MASK;
                signature_index <= 4'd0;
                current_hints = $clog2(current_mask[9:0] | current_mask[4:0]) + 
                               $clog2(current_mask[9:5]);
                for (i = 0; i < n_in; i = i + 1) begin
                    signatures[i] = distinct_cards[i] & current_mask;
                end
            end

            CHECK_MASK: begin
                signature_match = 1'b0;
                for (i = 0; i < n_in; i = i + 1) begin
                    for (j = i + 1; j < n_in; j = j + 1) begin
                        if (signatures[i] == signatures[j]) begin
                            signature_match = 1'b1;
                        end
                    end
                end
                if (!signature_match && current_hints < min_hints) begin
                    min_hints = current_hints;
                end
                next_state = NEXT_MASK;
            end

            NEXT_MASK: begin
                current_mask <= current_mask + 10'd1;
                if (current_mask == 10'd1024) begin
                    next_state = DONE_STATE;
                    answer <= min_hints;
                end else begin
                    next_state = INIT_MASK;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule