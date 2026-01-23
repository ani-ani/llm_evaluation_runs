module beautiful_sequence(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,  // count of 0s
    input [7:0] b,  // count of 1s
    input [7:0] c,  // count of 2s
    input [7:0] d,  // count of 3s
    output reg [7:0] seq_out [0:31],  // output sequence (max 32 elements)
    output reg [5:0] seq_len,          // length of output sequence
    output reg done
);

// State declarations
localparam [1:0] IDLE     = 2'd0;
localparam [1:0] TRY_START = 2'd1;
localparam [1:0] RUN_SEQ  = 2'd2;
localparam [1:0] FINISH   = 2'd3;

// Internal registers
reg [7:0] counts [0:3];      // counts for 0,1,2,3
reg [7:0] temp_counts [0:3]; // temporary copy for construction
reg [5:0] idx;               // index in sequence
reg [2:0] current_num;       // current number in sequence
reg [1:0] state;             // state machine
reg [2:0] attempts;          // which start we are trying
reg [7:0] seq_idx_reg;       // track sequence index for next element

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all registers
        state <= IDLE;
        done <= 1'b0;
        seq_len <= 6'd0;
        attempts <= 3'd0;
        idx <= 6'd0;
        current_num <= 3'd0;
        seq_idx_reg <= 8'd0;
        counts[0] <= 8'd0;
        counts[1] <= 8'd0;
        counts[2] <= 8'd0;
        counts[3] <= 8'd0;
        temp_counts[0] <= 8'd0;
        temp_counts[1] <= 8'd0;
        temp_counts[2] <= 8'd0;
        temp_counts[3] <= 8'd0;
        for (i = 0; i < 32; i = i + 1) begin
            seq_out[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Initialize counts from inputs
                    counts[0] <= a;
                    counts[1] <= b;
                    counts[2] <= c;
                    counts[3] <= d;
                    attempts <= 3'd0;
                    state <= TRY_START;
                end
            end
            
            TRY_START: begin
                if (attempts < 4'd4) begin
                    // Check if this starting point has any count
                    if ((attempts == 3'd0 && counts[0] > 8'd0) ||
                        (attempts == 3'd1 && counts[1] > 8'd0) ||
                        (attempts == 3'd2 && counts[2] > 8'd0) ||
                        (attempts == 3'd3 && counts[3] > 8'd0)) begin
                        // Make copy of counts
                        temp_counts[0] <= counts[0];
                        temp_counts[1] <= counts[1];
                        temp_counts[2] <= counts[2];
                        temp_counts[3] <= counts[3];
                        // Set first element
                        seq_out[0] <= {5'd0, attempts};
                        temp_counts[attempts] <= temp_counts[attempts] - 8'd1;
                        current_num <= attempts;
                        idx <= 6'd1;  // Next position to fill
                        seq_idx_reg <= 8'd1;
                        state <= RUN_SEQ;
                    end else begin
                        attempts <= attempts + 3'd1;
                    end
                end else begin
                    // All attempts failed
                    state <= FINISH;
                end
            end
            
            RUN_SEQ: begin
                // Check if we've used all numbers
                if (temp_counts[0] == 8'd0 && temp_counts[1] == 8'd0 &&
                    temp_counts[2] == 8'd0 && temp_counts[3] == 8'd0) begin
                    // Success! All numbers used
                    seq_len <= idx;
                    state <= FINISH;
                end else if (idx < 6'd32) begin
                    // Try to add next element based on current_num
                    case (current_num)
                        3'd0: begin  // current is 0, can only go to 1
                            if (temp_counts[1] > 8'd0) begin
                                seq_out[idx] <= {5'd0, 3'd1};
                                temp_counts[1] <= temp_counts[1] - 8'd1;
                                current_num <= 3'd1;
                                idx <= idx + 6'd1;
                            end else begin
                                // Can't continue, try next start
                                attempts <= attempts + 3'd1;
                                state <= TRY_START;
                            end
                        end
                        3'd1: begin  // current is 1, can go to 0 or 2
                            if (temp_counts[0] > 8'd0) begin
                                seq_out[idx] <= {5'd0, 3'd0};
                                temp_counts[0] <= temp_counts[0] - 8'd1;
                                current_num <= 3'd0;
                                idx <= idx + 6'd1;
                            end else if (temp_counts[2] > 8'd0) begin
                                seq_out[idx] <= {5'd0, 3'd2};
                                temp_counts[2] <= temp_counts[2] - 8'd1;
                                current_num <= 3'd2;
                                idx <= idx + 6'd1;
                            end else begin
                                // Can't continue, try next start
                                attempts <= attempts + 3'd1;
                                state <= TRY_START;
                            end
                        end
                        3'd2: begin  // current is 2, can go to 1 or 3
                            if (temp_counts[3] > 8'd0) begin
                                seq_out[idx] <= {5'd0, 3'd3};
                                temp_counts[3] <= temp_counts[3] - 8'd1;
                                current_num <= 3'd3;
                                idx <= idx + 6'd1;
                            end else if (temp_counts[1] > 8'd0) begin
                                seq_out[idx] <= {5'd0, 3'd1};
                                temp_counts[1] <= temp_counts[1] - 8'd1;
                                current_num <= 3'd1;
                                idx <= idx + 6'd1;
                            end else begin
                                // Can't continue, try next start
                                attempts <= attempts + 3'd1;
                                state <= TRY_START;
                            end
                        end
                        3'd3: begin  // current is 3, can only go to 2
                            if (temp_counts[2] > 8'd0) begin
                                seq_out[idx] <= {5'd0, 3'd2};
                                temp_counts[2] <= temp_counts[2] - 8'd1;
                                current_num <= 3'd2;
                                idx <= idx + 6'd1;
                            end else begin
                                // Can't continue, try next start
                                attempts <= attempts + 3'd1;
                                state <= TRY_START;
                            end
                        end
                    endcase
                end else begin
                    // Sequence too long, try next start
                    attempts <= attempts + 3'd1;
                    state <= TRY_START;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                // Stay in finish state until reset or new start
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule