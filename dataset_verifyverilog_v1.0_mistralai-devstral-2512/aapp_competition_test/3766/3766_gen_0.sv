module hanabi_hints_minimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] card_type [0:24],
    input wire [0:24] valid_types,
    input wire [6:0] num_cards,
    output reg [3:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [10:0] IDLE = 11'd0;
    localparam [10:0] COMPUTE = 11'd1;
    localparam [10:0] DONE_STATE = 11'd1025;

    // Internal registers
    reg [10:0] state;
    reg [9:0] hint_mask;
    reg [3:0] min_hints;
    reg [3:0] current_hint_count;
    reg [7:0] card_reg [0:24];
    reg [0:24] valid_reg;
    reg [6:0] num_cards_reg;
    reg [7:0] signature [0:24];
    reg [0:24] unique_check;
    reg all_unique;
    integer i, j;

    // FSM for control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            hint_mask <= 10'd0;
            min_hints <= 4'd10;
            current_hint_count <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 4'd0;
            for (i = 0; i < 25; i = i + 1) begin
                card_reg[i] <= 8'd0;
                valid_reg[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        // Store inputs
                        for (i = 0; i < 25; i = i + 1) begin
                            card_reg[i] <= card_type[i];
                            valid_reg[i] <= valid_types[i];
                        end
                        num_cards_reg <= num_cards;
                        state <= COMPUTE;
                        hint_mask <= 10'd0;
                        min_hints <= 4'd10;
                    end
                end

                COMPUTE: begin
                    // Compute signatures for current hint_mask
                    for (i = 0; i < 25; i = i + 1) begin
                        if (valid_reg[i]) begin
                            signature[i] <= hint_mask & card_reg[i];
                        end else begin
                            signature[i] <= 8'd0;
                        end
                    end

                    // Check uniqueness
                    all_unique = 1'b1;
                    for (i = 0; i < 24; i = i + 1) begin
                        if (valid_reg[i]) begin
                            for (j = i + 1; j < 25; j = j + 1) begin
                                if (valid_reg[j] && (signature[i] == signature[j])) begin
                                    all_unique = 1'b0;
                                end
                            end
                        end
                    end

                    // Count hints in current mask
                    current_hint_count = 4'd0;
                    for (i = 0; i < 10; i = i + 1) begin
                        if (hint_mask[i]) begin
                            current_hint_count = current_hint_count + 4'd1;
                        end
                    end

                    // Update minimum if unique
                    if (all_unique && (current_hint_count < min_hints)) begin
                        min_hints <= current_hint_count;
                    end

                    // Next hint mask
                    if (hint_mask == 10'd1023) begin
                        state <= DONE_STATE;
                    end else begin
                        hint_mask <= hint_mask + 10'd1;
                    end
                end

                DONE_STATE: begin
                    result <= min_hints;
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule