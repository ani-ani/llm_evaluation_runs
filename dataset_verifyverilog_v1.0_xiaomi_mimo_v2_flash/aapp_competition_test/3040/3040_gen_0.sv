module longest_repeated_substring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [4:0] len,
    output reg [7:0] result [0:15],
    output reg [4:0] out_len,
    output reg done
);

// State machine states
localparam [3:0] IDLE        = 4'd0;
localparam [3:0] CHECK_L     = 4'd1;
localparam [3:0] INIT_IJ     = 4'd2;
localparam [3:0] COMPARE     = 4'd3;
localparam [3:0] NEXT_J      = 4'd4;
localparam [3:0] NEXT_I      = 4'd5;
localparam [3:0] UPDATE_BEST = 4'd6;
localparam [3:0] DECREMENT_L = 4'd7;
localparam [3:0] OUTPUT_RES  = 4'd8;
localparam [3:0] DONE_STATE  = 4'd9;

reg [3:0] state, next_state;
reg [4:0] L;           // current substring length
reg [4:0] i, j, k;     // loop counters
reg [7:0] best_substring [0:15];
reg [4:0] best_len;
reg found_repeated;
reg compare_result;
reg [4:0] valid_len;
reg [7:0] char1, char2;
reg [4:0] loop_limit;

integer m;

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start && len > 16'd1) next_state = CHECK_L;
            else if (start && len <= 16'd1) next_state = OUTPUT_RES;
            else next_state = IDLE;
        end
        CHECK_L: begin
            if (L >= 16'd2) next_state = INIT_IJ;
            else next_state = OUTPUT_RES;
        end
        INIT_IJ: next_state = COMPARE;
        COMPARE: next_state = COMPARE;  // default, overridden in seq logic
        NEXT_J: next_state = COMPARE;
        NEXT_I: next_state = COMPARE;
        UPDATE_BEST: next_state = NEXT_J;
        DECREMENT_L: next_state = CHECK_L;
        OUTPUT_RES: next_state = DONE_STATE;
        DONE_STATE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        done <= 1'b0;
        out_len <= 5'd0;
        L <= 5'd0;
        i <= 5'd0;
        j <= 5'd0;
        k <= 5'd0;
        found_repeated <= 1'b0;
        best_len <= 5'd0;
        valid_len <= 5'd16;
        compare_result <= 1'b0;
        loop_limit <= 5'd0;
        char1 <= 8'd0;
        char2 <= 8'd0;
        for (m = 0; m < 16; m = m + 1) begin
            result[m] <= 8'd0;
            best_substring[m] <= 8'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                found_repeated <= 1'b0;
                best_len <= 5'd0;
                k <= 5'd0;
                for (m = 0; m < 16; m = m + 1) begin
                    best_substring[m] <= 8'd0;
                end
                if (start) begin
                    valid_len <= (len > 16'd16) ? 5'd16 : len;
                    if (len > 16'd1) begin
                        L <= (len > 16'd16) ? 5'd16 : len;
                    end else begin
                        L <= 5'd1;
                    end
                end
            end
            
            CHECK_L: begin
                k <= 5'd0;
            end
            
            INIT_IJ: begin
                i <= 5'd0;
                j <= 5'd1;
                found_repeated <= 1'b0;
                loop_limit <= valid_len - L + 5'd1;
            end
            
            COMPARE: begin
                if (k < L && (i + k) < valid_len && (j + k) < valid_len) begin
                    // Continue character comparison
                    char1 <= arr[i + k];
                    char2 <= arr[j + k];
                    k <= k + 5'd1;
                    // Stay in COMPARE if not done
                    if (k + 5'd1 < L) next_state <= COMPARE;
                    else next_state <= COMPARE; // will check equality next cycle
                end else if (k == L) begin
                    // Finished comparing L characters
                    if (char1 == char2 && !found_repeated) begin
                        // Found a repeat for this L for first time
                        found_repeated <= 1'b1;
                        k <= 5'd0;
                        next_state <= COMPARE; // continue checking this j
                    end else if (char1 == char2 && found_repeated) begin
                        // Already found repeat, update best
                        if (L > best_len || (L == best_len)) begin
                            best_len <= L;
                            for (m = 0; m < 16; m = m + 1) begin
                                if (m < L) best_substring[m] <= arr[i + m];
                                else best_substring[m] <= 8'd0;
                            end
                        end
                        next_state <= NEXT_J;
                    end else begin
                        // Mismatch
                        next_state <= NEXT_J;
                    end
                end else begin
                    // Not enough characters for full comparison
                    next_state <= NEXT_J;
                end
            end
            
            NEXT_J: begin
                k <= 5'd0;
                if (j + 5'd1 < loop_limit) begin
                    j <= j + 5'd1;
                    next_state <= COMPARE;
                end else begin
                    next_state <= NEXT_I;
                end
            end
            
            NEXT_I: begin
                if (i + 5'd1 < loop_limit - 5'd1) begin
                    i <= i + 5'd1;
                    j <= i + 5'd2;
                    k <= 5'd0;
                    next_state <= COMPARE;
                end else begin
                    next_state <= DECREMENT_L;
                end
            end
            
            UPDATE_BEST: begin
                best_len <= L;
                for (m = 0; m < 16; m = m + 1) begin
                    if (m < L) best_substring[m] <= arr[i + m];
                    else best_substring[m] <= 8'd0;
                end
            end
            
            DECREMENT_L: begin
                if (L > 2) begin
                    L <= L - 5'd1;
                end else begin
                    L <= 5'd1;
                end
            end
            
            OUTPUT_RES: begin
                if (len <= 5'd1) begin
                    // Special case: single char or empty
                    for (m = 0; m < 16; m = m + 1) begin
                        if (m == 0 && len == 5'd1) result[m] <= arr[0];
                        else result[m] <= 8'd0;
                    end
                    out_len <= (len == 5'd1) ? 5'd1 : 5'd0;
                end else if (best_len == 5'd0) begin
                    // No repeated substring found, output first char
                    for (m = 0; m < 16; m = m + 1) begin
                        if (m == 0) result[m] <= arr[0];
                        else result[m] <= 8'd0;
                    end
                    out_len <= 5'd1;
                end else begin
                    // Output best substring
                    for (m = 0; m < 16; m = m + 1) begin
                        if (m < best_len) result[m] <= best_substring[m];
                        else result[m] <= 8'd0;
                    end
                    out_len <= best_len;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule