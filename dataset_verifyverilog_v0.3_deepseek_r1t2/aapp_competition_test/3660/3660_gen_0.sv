module sticker_cover #(
    parameter MSG_LEN = 8,
    parameter NUM_STICKERS = 4,
    parameter STICKER_MAX_LEN = 4,
    parameter PRICE_WIDTH = 20,
    parameter CHAR_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] msg [0:MSG_LEN-1],
    input wire [CHAR_WIDTH-1:0] sticker_word [0:NUM_STICKERS-1] [0:STICKER_MAX_LEN-1],
    input wire [3:0] sticker_len [0:NUM_STICKERS-1],
    input wire [PRICE_WIDTH-1:0] sticker_price [0:NUM_STICKERS-1],
    output reg [PRICE_WIDTH-1:0] min_cost,
    output reg possible,
    output reg done
);

// State declarations
localparam [1:0] IDLE      = 2'd0;
localparam [1:0] PREPARE   = 2'd1;
localparam [1:0] DP_ITER   = 2'd2;
localparam [1:0] FINISHED  = 2'd3;

reg [1:0] state;
reg [1:0] next_state;

// Match table: which stickers match at each position
reg [NUM_STICKERS-1:0] match_table [0:MSG_LEN-1];

// DP arrays
reg [7:0] dp_state [0:MSG_LEN]; // Coverage states per position
reg [PRICE_WIDTH-1:0] dp_cost [0:MSG_LEN];
reg dp_valid [0:MSG_LEN];

// Counters
reg [3:0] pos_counter;
reg [3:0] sticker_counter;
reg [7:0] state_idx;

// Current best cost
reg [PRICE_WIDTH-1:0] best_cost;

// Helper function: sticker matches at position?
function automatic match_sticker;
    input [3:0] pos;
    input [3:0] sticker_idx;
    integer i;
    reg match;
    begin
        match = 1'b1;
        for (i = 0; i < sticker_len[sticker_idx]; i = i + 1) begin
            if ((pos + i >= MSG_LEN) || (msg[pos + i] != sticker_word[sticker_idx][i])) begin
                match = 1'b0;
            end
        end
        match_sticker = match;
    end
endfunction

// Helper function: update coverage state
function automatic [7:0] update_coverage;
    input [7:0] current;
    input [3:0] start;
    input [3:0] len;
    integer i;
    reg [1:0] val;
    begin
        update_coverage = current;
        for (i = 0; i < len; i = i + 1) begin
            if (start + i < 4) begin
                val = update_coverage[(start + i)*2 +: 2];
                if (val == 2'b00) val = 2'b01;
                else if (val == 2'b01) val = 2'b10;
                else val = 2'b11;
                update_coverage[(start + i)*2 +: 2] = val;
            end
        end
    end
endfunction

// Helper function: coverage complete?
function automatic is_covered;
    input [7:0] cov;
    input [3:0] pos;
    integer i;
    begin
        is_covered = 1'b1;
        for (i = 0; i < 4; i = i + 1) begin
            if (i == (MSG_LEN - pos)) break;
            if (cov[i*2 +: 2] == 2'b00) begin
                is_covered = 1'b0;
            end
        end
    end
endfunction

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all arrays and outputs
        done <= 1'b0;
        possible <= 1'b0;
        min_cost <= 0;
        state <= IDLE;
        
        for (i = 0; i < MSG_LEN; i = i + 1) begin
            match_table[i] <= {NUM_STICKERS{1'b0}};
        end
        
        for (i = 0; i <= MSG_LEN; i = i + 1) begin
            dp_valid[i] <= 1'b0;
            dp_cost[i] <= {PRICE_WIDTH{1'b1}};
            dp_state[i] <= 8'd0;
        end
        
        // Initial DP state
        dp_valid[0] <= 1'b1;
        dp_cost[0] <= 0;
        dp_state[0] <= 8'd0;
        
        best_cost <= {PRICE_WIDTH{1'b1}};
        pos_counter <= 0;
        sticker_counter <= 0;
        state_idx <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                possible <= 1'b0;
                if (start) begin
                    // Initialize DP tables
                    dp_valid[0] <= 1'b1;
                    dp_cost[0] <= 0;
                    dp_state[0] <= 8'd0;
                    
                    for (i = 1; i <= MSG_LEN; i = i + 1) begin
                        dp_valid[i] <= 1'b0;
                        dp_cost[i] <= {PRICE_WIDTH{1'b1}};
                        dp_state[i] <= 8'd0;
                    end
                    
                    best_cost <= {PRICE_WIDTH{1'b1}};
                    pos_counter <= 0;
                    sticker_counter <= 0;
                    state <= PREPARE;
                end
            end
            
            PREPARE: begin
                // Build match table for current position
                if (pos_counter < MSG_LEN) begin
                    if (sticker_counter < NUM_STICKERS) begin
                        match_table[pos_counter][sticker_counter] <= match_sticker(pos_counter, sticker_counter);
                        sticker_counter <= sticker_counter + 1;
                    end
                    else begin
                        sticker_counter <= 0;
                        pos_counter <= pos_counter + 1;
                    end
                end
                else begin
                    state <= DP_ITER;
                    pos_counter <= 0;
                end
            end
            
            DP_ITER: begin
                if (pos_counter < MSG_LEN) begin
                    if (dp_valid[pos_counter]) begin
                        // Check possible stickers
                        if (sticker_counter < NUM_STICKERS) begin
                            if (match_table[pos_counter][sticker_counter]) begin
                                // Apply sticker
                                state_idx <= update_coverage(dp_state[pos_counter], 0, sticker_len[sticker_counter]);
                                
                                // Only update if new state is valid
                                if (state_idx[1:0] != 2'b11) begin
                                    if (dp_cost[pos_counter] + sticker_price[sticker_counter] < dp_cost[pos_counter+1]) begin
                                        dp_cost[pos_counter+1] <= dp_cost[pos_counter] + sticker_price[sticker_counter];
                                        dp_state[pos_counter+1] <= {state_idx[5:0], 2'b00}; // Shift window
                                        dp_valid[pos_counter+1] <= 1'b1;
                                    end
                                end
                                
                                // Check if this leads to complete coverage
                                if (is_covered(state_idx, pos_counter)) begin
                                    if (dp_cost[pos_counter] + sticker_price[sticker_counter] < best_cost) begin
                                        best_cost <= dp_cost[pos_counter] + sticker_price[sticker_counter];
                                    end
                                end
                            end
                            sticker_counter <= sticker_counter + 1;
                        end
                        else begin
                            // Advance to next position
                            sticker_counter <= 0;
                            pos_counter <= pos_counter + 1;
                        end
                    end
                    else begin
                        // Skip invalid state
                        pos_counter <= pos_counter + 1;
                    end
                end
                else begin
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                if (best_cost != {PRICE_WIDTH{1'b1}}) begin
                    min_cost <= best_cost;
                    possible <= 1'b1;
                end
                else begin
                    min_cost <= 0;
                    possible <= 1'b0;
                end
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule