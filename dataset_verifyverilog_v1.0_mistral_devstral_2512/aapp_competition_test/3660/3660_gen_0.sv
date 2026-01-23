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

// State encoding: IDLE=0, PREPARE=1, DP_ITER=2, FINISHED=3
localparam [1:0] IDLE = 2'd0;
localparam [1:0] PREPARE = 2'd1;
localparam [1:0] DP_ITER = 2'd2;
localparam [1:0] FINISHED = 2'd3;

reg [1:0] state;

// Precomputed match table: for each position, which stickers match starting there
reg [NUM_STICKERS-1:0] match_table [0:MSG_LEN-1];

// DP state: coverage for current position and next 3 positions (4 total)
// Each position uses 2 bits: 00=uncovered, 01=covered once, 10=covered twice, 11=invalid
reg [7:0] dp_coverage [0:255];
reg [PRICE_WIDTH-1:0] dp_cost [0:255];
reg dp_valid [0:255];

// Current DP iteration
reg [3:0] current_pos;
reg [7:0] current_state_idx;
reg [PRICE_WIDTH-1:0] best_cost;
reg best_possible;

// Helper: check if sticker matches at position
function automatic [0:0] sticker_matches(
    input [CHAR_WIDTH-1:0] msg [0:MSG_LEN-1],
    input [CHAR_WIDTH-1:0] sticker [0:STICKER_MAX_LEN-1],
    input [3:0] sticker_len,
    input [3:0] pos
);
    integer i;
    begin
        sticker_matches = 1'b1;
        if (pos + sticker_len > MSG_LEN) begin
            sticker_matches = 1'b0;
            return;
        end
        for (i = 0; i < sticker_len; i = i + 1) begin
            if (msg[pos + i] !== sticker[i]) begin
                sticker_matches = 1'b0;
                return;
            end
        end
    end
endfunction

// Helper: update coverage when adding a sticker
function automatic [7:0] update_coverage(
    input [7:0] old_cov,
    input [3:0] start,
    input [3:0] len
);
    reg [7:0] new_cov;
    integer i;
    reg [1:0] curr;
    begin
        new_cov = old_cov;
        for (i = 0; i < len && start + i < 4; i = i + 1) begin
            curr = new_cov[(start + i) * 2 +: 2];
            if (curr == 2'b10) begin
                new_cov = 8'b11111111;
                return new_cov;
            end else if (curr == 2'b01) begin
                new_cov[(start + i) * 2 +: 2] = 2'b10;
            end else if (curr == 2'b00) begin
                new_cov[(start + i) * 2 +: 2] = 2'b01;
            end
        end
        update_coverage = new_cov;
    end
endfunction

// Helper: check if coverage is complete and valid
function automatic [0:0] is_coverage_complete(
    input [7:0] cov,
    input [3:0] msg_len
);
    integer i;
    reg [1:0] curr;
    begin
        is_coverage_complete = 1'b1;
        for (i = 0; i < 4; i = i + 1) begin
            if (i < msg_len) begin
                curr = cov[i * 2 +: 2];
                if (curr == 2'b00 || curr == 2'b11) begin
                    is_coverage_complete = 1'b0;
                    return;
                end
            end
        end
    end
endfunction

integer i, j, k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        possible <= 1'b0;
        min_cost <= 0;
        current_pos <= 0;
        current_state_idx <= 0;
        best_cost <= {PRICE_WIDTH{1'b1}};
        best_possible <= 1'b0;
        for (i = 0; i < MSG_LEN; i = i + 1) begin
            match_table[i] <= 0;
        end
        for (i = 0; i < 256; i = i + 1) begin
            dp_coverage[i] <= 0;
            dp_cost[i] <= 0;
            dp_valid[i] <= 1'b0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PREPARE;
                    current_pos <= 0;
                    current_state_idx <= 0;
                    best_cost <= {PRICE_WIDTH{1'b1}};
                    best_possible <= 1'b0;
                    done <= 1'b0;
                end
            end
            
            PREPARE: begin
                if (current_pos < MSG_LEN) begin
                    match_table[current_pos] <= 0;
                    for (j = 0; j < NUM_STICKERS; j = j + 1) begin
                        if (sticker_matches(msg, sticker_word[j], sticker_len[j], current_pos)) begin
                            match_table[current_pos][j] <= 1'b1;
                        end
                    end
                    current_pos <= current_pos + 1;
                end else begin
                    dp_coverage[0] <= 8'b00000000;
                    dp_cost[0] <= 0;
                    dp_valid[0] <= 1'b1;
                    current_pos <= 0;
                    current_state_idx <= 0;
                    state <= DP_ITER;
                end
            end
            
            DP_ITER: begin
                if (current_pos < MSG_LEN) begin
                    if (dp_valid[current_state_idx]) begin
                        reg [7:0] cov = dp_coverage[current_state_idx];
                        reg [PRICE_WIDTH-1:0] cost = dp_cost[current_state_idx];
                        
                        reg [1:0] curr_cov = cov[1:0];
                        
                        if (curr_cov == 2'b00) begin
                            for (k = 0; k < NUM_STICKERS; k = k + 1) begin
                                if (match_table[current_pos][k]) begin
                                    reg [7:0] new_cov = update_coverage(cov, 0, sticker_len[k]);
                                    if (new_cov != 8'b11111111) begin
                                        reg [7:0] next_cov = {new_cov[5:0], 2'b00};
                                        reg [PRICE_WIDTH-1:0] new_cost = cost + sticker_price[k];
                                        if (!best_possible || new_cost < best_cost) begin
                                            best_cost <= new_cost;
                                            best_possible <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end else begin
                            reg [7:0] shifted_cov = {cov[5:0], 2'b00};
                            if (is_coverage_complete(shifted_cov, MSG_LEN - current_pos - 1)) begin
                                if (!best_possible || cost < best_cost) begin
                                    best_cost <= cost;
                                    best_possible <= 1'b1;
                                end
                            end
                            for (k = 0; k < NUM_STICKERS; k = k + 1) begin
                                if (match_table[current_pos][k]) begin
                                    reg [7:0] new_cov = update_coverage(cov, 0, sticker_len[k]);
                                    if (new_cov != 8'b11111111) begin
                                        reg [7:0] next_cov = {new_cov[5:0], 2'b00};
                                        reg [PRICE_WIDTH-1:0] new_cost = cost + sticker_price[k];
                                        if (!best_possible || new_cost < best_cost) begin
                                            best_cost <= new_cost;
                                            best_possible <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    if (current_state_idx < 255) begin
                        current_state_idx <= current_state_idx + 1;
                    end else begin
                        current_state_idx <= 0;
                        current_pos <= current_pos + 1;
                    end
                end else begin
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                if (best_possible) begin
                    min_cost <= best_cost;
                    possible <= 1'b1;
                end else begin
                    min_cost <= 0;
                    possible <= 1'b0;
                end
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule