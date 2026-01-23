module visual_parser (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] num_pairs, // not used
    input [7:0] tl_valid,
    input [2:0] tl_row [0:7],
    input [2:0] tl_col [0:7],
    input [7:0] br_valid,
    input [2:0] br_row [0:7],
    input [2:0] br_col [0:7],
    output reg [2:0] match_idx [0:7],
    output reg valid,
    output reg done
);

// Registers for captured inputs
reg [7:0] captured_tl_valid;
reg [2:0] captured_tl_row [0:7];
reg [2:0] captured_tl_col [0:7];
reg [7:0] captured_br_valid;
reg [2:0] captured_br_row [0:7];
reg [2:0] captured_br_col [0:7];

// State machine
typedef enum {IDLE, DONE} state_t;
reg state_t state;
// Other registers not needed

output reg [2:0] match_idx [0:7];
output reg valid;
output reg done;

always @(*) begin
    match_idx <= 'd0;
    valid <=0;
    done <=0;
end

// Clock and reset logic
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset
        captured_tl_valid <= 'd0;
        captured_tl_row <= 'd0;
        captured_tl_col <= 'd0;
        captured_br_valid <= 'd0;
        captured_br_row <= 'd0;
        captured_br_col <= 'd0;
        state <= IDLE;
        valid <=0;
        done <=0;
        match_idx <= 'd0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                // Capture inputs
                captured_tl_valid <= tl_valid;
                captured_tl_row <= tl_row;
                captured_tl_col <= tl_col;
                captured_br_valid <= br_valid;
                captured_br_row <= br_row;
                captured_br_col <= br_col;

                // Compute N and M
                integer N =0, M=0;
                for (int i=0; i<8; i++) begin
                    if (captured_tl_valid[i]) N +=1;
                    if (captured_br_valid[i]) M +=1;
                end

                if (N != M) begin
                    valid <=0;
                    done <=1;
                    state <= DONE;
                end else if (N ==0) begin
                    valid <=1;
                    done <=1;
                    state <= DONE;
                end else begin
                    // Check identity mapping
                    integer valid_flag =1;
                    for (int i=0; i<8; i++) begin
                        if (captured_tl_valid[i]) begin
                            if (!captured_br_valid[i] || \
                                captured_tl_row[i] >= captured_br_row[i] || \
                                captured_tl_col[i] >= captured_br_col[i]) begin
                                valid_flag =0;
                            end
                        end
                    end
                    if (valid_flag) begin
                        for (int i=0; i<8; i++) begin
                            if (captured_tl_valid[i]) begin
                                match_idx[i] = i; // match to same index
                            end
                        end
                        valid <=1;
                        done <=1;
                        state <= DONE;
                    end else begin
                        valid <=0;
                        done <=1;
                        state <= DONE;
                    end
                end
            end else begin
                // Stay in IDLE
                state <= IDLE;
            end
        end else begin // DONE state
            state <= DONE;
        end
    end
end

endmodule