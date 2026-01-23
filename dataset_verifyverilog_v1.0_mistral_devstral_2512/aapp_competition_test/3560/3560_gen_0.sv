module barbarian_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire op_type,          // 0 = show word, 1 = query
    input wire [7:0] char0, char1, char2, char3, char4, char5, char6, char7,
    input wire [3:0] str_len,    // 1-8
    input wire [1:0] barbarian_idx,  // 0-3 (maps to 1-4)
    output reg [7:0] result,
    output reg done
);

parameter MAX_SHOWN = 8;
parameter MAX_LEN = 8;

// Barbarian words (pre-loaded for testbench)
reg [7:0] barb_words [0:3][0:7];
reg [3:0] barb_lens [0:3];

// Shown words storage
reg [7:0] shown_words [0:7][0:7];
reg [3:0] shown_lens [0:7];
reg [3:0] shown_count;

// FSM states
reg [2:0] state;
localparam IDLE = 3'd0;
localparam STORE = 3'd1;
localparam QUERY_INIT = 3'd2;
localparam QUERY_MATCH = 3'd3;
localparam QUERY_NEXT = 3'd4;
localparam DONE = 3'd5;

// Query registers
reg [3:0] shown_idx;
reg [3:0] pos_idx;
reg [3:0] match_len;
reg [7:0] match_count;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shown_count <= 0;
        result <= 0;
        done <= 0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    if (op_type == 0) begin
                        state <= STORE;
                    end else begin
                        shown_idx <= 0;
                        match_count <= 0;
                        state <= QUERY_INIT;
                    end
                end
            end
            
            STORE: begin
                if (shown_count < MAX_SHOWN) begin
                    shown_words[shown_count][0] <= char0;
                    shown_words[shown_count][1] <= char1;
                    shown_words[shown_count][2] <= char2;
                    shown_words[shown_count][3] <= char3;
                    shown_words[shown_count][4] <= char4;
                    shown_words[shown_count][5] <= char5;
                    shown_words[shown_count][6] <= char6;
                    shown_words[shown_count][7] <= char7;
                    shown_lens[shown_count] <= str_len;
                    shown_count <= shown_count + 1;
                end
                state <= DONE;
            end
            
            QUERY_INIT: begin
                pos_idx <= 0;
                match_len <= 0;
                state <= QUERY_MATCH;
            end
            
            QUERY_MATCH: begin
                if (shown_idx < shown_count) begin
                    if (pos_idx + match_len < shown_lens[shown_idx] && 
                        match_len < barb_lens[barbarian_idx]) begin
                        if (shown_words[shown_idx][pos_idx + match_len] == 
                            barb_words[barbarian_idx][match_len]) begin
                            match_len <= match_len + 1;
                        end else begin
                            pos_idx <= pos_idx + 1;
                            match_len <= 0;
                        end
                    end else if (match_len == barb_lens[barbarian_idx]) begin
                        match_count <= match_count + 1;
                        state <= QUERY_NEXT;
                    end else begin
                        state <= QUERY_NEXT;
                    end
                end else begin
                    result <= match_count;
                    state <= DONE;
                end
            end
            
            QUERY_NEXT: begin
                shown_idx <= shown_idx + 1;
                state <= QUERY_INIT;
            end
            
            DONE: begin
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule