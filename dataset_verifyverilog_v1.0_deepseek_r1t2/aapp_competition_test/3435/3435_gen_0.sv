module SpyIDCounter #(
    parameter MAX_N = 8,
    parameter MAX_M = 6
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] pattern_len,
    input wire [MAX_M-1:0] pattern_mask,
    output reg [15:0] result,
    output reg done
);

    localparam STATE_COUNT = 2 * (2 ** (MAX_M - 1));
    
    reg [7:0] dp_vector [0:STATE_COUNT-1];
    reg [7:0] next_dp_vector [0:STATE_COUNT-1];
    reg [3:0] current_pos;
    reg computing;
    reg start_delayed;
    
    wire [MAX_M-1:0] mask_eff = pattern_mask & ((1 << pattern_len) - 1);
    
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            computing <= 1'b0;
            current_pos <= 4'd0;
            start_delayed <= 1'b0;
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                dp_vector[i] <= 8'd0;
            end
        end else begin
            done <= 1'b0;
            start_delayed <= start;
            
            if (start && !start_delayed) begin
                current_pos <= 4'd0;
                
                if (pattern_len > n) begin
                    result <= 16'd0;
                    done <= 1'b1;
                    computing <= 1'b0;
                end else if (pattern_len == n) begin
                    integer wildcards = n - popcount(mask_eff);
                    result <= (wildcards >= 0) ? (16'd1 << wildcards) : 16'd0;
                    done <= 1'b1;
                    computing <= 1'b0;
                end else begin
                    for (i = 0; i < STATE_COUNT; i = i + 1) begin
                        dp_vector[i] <= 8'd0;
                    end
                    dp_vector[4'd0] <= 8'd1;
                    computing <= 1'b1;
                end
            end else if (computing) begin
                if (current_pos < n) begin
                    for (i = 0; i < STATE_COUNT; i = i + 1) begin
                        next_dp_vector[i] <= 8'd0;
                    end
                    
                    for (i = 0; i < STATE_COUNT; i = i + 1) begin
                        if (dp_vector[i] != 8'd0) begin
                            wire has_match = i[MAX_M-1];
                            wire [MAX_M-2:0] suffix = i[MAX_M-2:0];
                            
                            for (j = 0; j < 2; j = j + 1) begin
                                wire [MAX_M-2:0] new_suffix = pattern_len > 1 ? ((suffix << 1) | j) & ((1 << (pattern_len-1)) - 1) : 1'd0;
                                reg match;
                                if (current_pos >= (pattern_len - 1)) begin
                                    wire [MAX_M-1:0] full_substring = {suffix, j};
                                    match = (full_substring & mask_eff) == mask_eff;
                                end else begin
                                    match = 1'b0;
                                end
                                wire new_has_match = has_match | match;
                                integer new_index = {new_has_match, new_suffix};
                                next_dp_vector[new_index] <= next_dp_vector[new_index] + dp_vector[i];
                            end
                        end
                    end
                    
                    for (i = 0; i < STATE_COUNT; i = i + 1) begin
                        dp_vector[i] <= next_dp_vector[i];
                    end
                    
                    current_pos <= current_pos + 1'b1;
                end else begin
                    computing <= 1'b0;
                    result <= 16'd0;
                    for (i = 0; i < STATE_COUNT; i = i + 1) begin
                        if (i[MAX_M-1]) begin
                            result <= result + dp_vector[i];
                        end
                    end
                    done <= 1'b1;
                end
            end
        end
    end
    
    function integer popcount(input [MAX_M-1:0] val);
        integer k;
        popcount = 0;
        for (k = 0; k < MAX_M; k = k + 1) begin
            if (val[k]) popcount = popcount + 1;
        end
    endfunction
endmodule