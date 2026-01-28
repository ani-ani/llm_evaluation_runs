module binary_town_election (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  k,
    input  wire [3:0]  v,
    input  wire [7:0]  p0, p1, p2, p3, p4, p5, p6, p7, p8,
    input  wire [7:0]  b0, b1, b2, b3, b4, b5, b6, b7, b8,
    output reg  [7:0]  best_b,
    output reg         done
);

    // State declarations
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] INIT            = 4'd1;
    localparam [3:0] SUBSET_LOOP     = 4'd2;
    localparam [3:0] COMPUTE_SUBSET  = 4'd3;
    localparam [3:0] ADD_PROB        = 4'd4;
    localparam [3:0] PREPARE_BV_LOOP = 4'd5;
    localparam [3:0] BV_LOOP         = 4'd6;
    localparam [3:0] COMPUTE_EXPECTED= 4'd7;
    localparam [3:0] UPDATE_MAX      = 4'd8;
    localparam [3:0] DONE_STATE      = 4'd9;
    
    reg [3:0] state, next_state;
    
    // Control registers
    reg [8:0]  subset;
    reg [7:0]  bv_candidate;
    reg [7:0]  residue;
    wire [3:0] num_other;
    assign num_other = v - 4'd1;
    
    // Probability array (128-bit)
    reg [127:0] prob [0:255];
    reg [127:0] prob_total;
    reg [127:0] expected;
    reg [127:0] max_expected;
    
    // Temporary registers
    reg [7:0]  temp_total_b;
    reg [3:0]  voter_idx;
    reg [7:0]  mod_res;
    reg [7:0]  total_w;
    
    // Popcount function
    function [3:0] popcount;
        input [7:0] in;
        integer j;
        begin
            popcount = 4'd0;
            for (j = 0; j < 8; j = j + 1) begin
                popcount = popcount + in[j];
            end
        end
    endfunction
    
    // Voter inputs array
    reg [7:0] p_arr [0:8];
    reg [7:0] b_arr [0:8];
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            best_b <= 8'd0;
            subset <= 9'd0;
            prob_total <= 128'd0;
            expected <= 128'd0;
            max_expected <= 128'd0;
            temp_total_b <= 8'd0;
            voter_idx <= 4'd0;
            
            // Initialize probability array
            for (i = 0; i < 256; i = i + 1) begin
                prob[i] <= 128'd0;
            end
            
            // Initialize input arrays
            for (i = 0; i < 9; i = i + 1) begin
                p_arr[i] <= 8'd0;
                b_arr[i] <= 8'd0;
            end
            
            bv_candidate <= 8'd0;
            residue <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input arrays
                        p_arr[0] <= p0;
                        p_arr[1] <= p1;
                        p_arr[2] <= p2;
                        p_arr[3] <= p3;
                        p_arr[4] <= p4;
                        p_arr[5] <= p5;
                        p_arr[6] <= p6;
                        p_arr[7] <= p7;
                        p_arr[8] <= p8;
                        
                        b_arr[0] <= b0;
                        b_arr[1] <= b1;
                        b_arr[2] <= b2;
                        b_arr[3] <= b3;
                        b_arr[4] <= b4;
                        b_arr[5] <= b5;
                        b_arr[6] <= b6;
                        b_arr[7] <= b7;
                        b_arr[8] <= b8;
                        
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Clear probability array
                    for (i = 0; i < 256; i = i + 1) begin
                        prob[i] <= 128'd0;
                    end
                    subset <= 9'd0;
                    state <= SUBSET_LOOP;
                end
                
                SUBSET_LOOP: begin
                    if (subset < (1 << num_other)) begin
                        temp_total_b <= 8'd0;
                        prob_total <= 128'd256; // 1 << 8
                        voter_idx <= 4'd0;
                        state <= COMPUTE_SUBSET;
                    end else begin
                        state <= PREPARE_BV_LOOP;
                    end
                end
                
                COMPUTE_SUBSET: begin
                    if (voter_idx < num_other) begin
                        // Check if current voter is in subset
                        if (subset[voter_idx]) begin
                            temp_total_b <= temp_total_b + b_arr[voter_idx];
                            prob_total <= (prob_total * p_arr[voter_idx]);
                        end else begin
                            prob_total <= (prob_total * (9'd256 - p_arr[voter_idx]));
                        end
                        voter_idx <= voter_idx + 4'd1;
                    end else begin
                        // Finished processing subset
                        mod_res = temp_total_b % (1 << k);
                        state <= ADD_PROB;
                    end
                end
                
                ADD_PROB: begin
                    prob[mod_res] <= prob[mod_res] + prob_total;
                    subset <= subset + 9'd1;
                    state <= SUBSET_LOOP;
                end
                
                PREPARE_BV_LOOP: begin
                    bv_candidate <= 8'd0;
                    max_expected <= 128'd0;
                    best_b <= 8'd0;
                    state <= BV_LOOP;
                end
                
                BV_LOOP: begin
                    if (bv_candidate < (1 << k)) begin
                        expected <= 128'd0;
                        residue <= 8'd0;
                        state <= COMPUTE_EXPECTED;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                COMPUTE_EXPECTED: begin
                    if (residue < 8'd256) begin
                        // Calculate (residue + bv_candidate) mod 2^k
                        total_w = (residue + bv_candidate);
                        mod_res = total_w % (1 << k);
                        
                        // Add prob[residue] * popcount
                        expected <= expected + (prob[residue] * popcount(mod_res));
                        residue <= residue + 8'd1;
                    end else begin
                        state <= UPDATE_MAX;
                    end
                end
                
                UPDATE_MAX: begin
                    if (expected > max_expected || (expected == max_expected && bv_candidate < best_b)) begin
                        max_expected <= expected;
                        best_b <= bv_candidate;
                    end
                    bv_candidate <= bv_candidate + 8'd1;
                    state <= BV_LOOP;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule