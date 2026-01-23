module hanabi_solver (
    input clk,
    input rst_n, // Active-low reset
    input start,
    input [4:0] unique_cards_count, // Number of unique cards (max 16)
    input [15:0] card_attributes [0:15], // Array of card attributes
    output reg [3:0] min_hints,
    output reg done
);

// State definitions
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE_STATE = 2'b10;

reg [1:0] state;
reg [10:0] mask_counter; // Counts from 0 to 1023
reg [3:0] min_hints;
reg done;

// Combinational validity check
wire validity;
always @(*) begin
    validity = 1'b1;
    integer i, j;
    localparam MAX_CARDS = 16;
    generate
        for (i=0; i<MAX_CARDS; i++) begin
            for (j=i+1; j<MAX_CARDS; j++) begin
                validity &= (unique_cards_count > j) ? ((card_attributes[i] ^ card_attributes[j]) & mask_counter) != 0 : 1'b1;
            end
        end
    endgenerate
end

// Compute popcount of mask_counter (10 bits)
assign pop = mask_counter[9] + mask_counter[8] + mask_counter[7] + mask_counter[6] + mask_counter[5] + 
            mask_counter[4] + mask_counter[3] + mask_counter[2] + mask_counter[1] + mask_counter[0];

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        mask_counter <= 0;
        min_hints <= 4'd10; // Initialize to maximum possible hints (10)
        done <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PROCESSING;
                mask_counter <= 0;
                min_hints <= 4'd10;
                done <= 0;
            end
        end else if (state == PROCESSING) begin
            if (mask_counter < 1023) begin
                mask_counter <= mask_counter + 1;
            end else begin
                state <= DONE_STATE;
                done <= 1;
            end
            // Check current mask and update min_hints if valid and better
            if (validity) begin
                if (pop < min_hints) begin
                    min_hints <= pop;
                end
            end
        end else if (state == DONE_STATE) begin
            // Remain in DONE state
        end
    end
end

endmodule