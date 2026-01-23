module morse_counter #(
    parameter MAX_LEN = 32,
    parameter MOD = 1000000007
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire bit_in,
    output reg [31:0] answer,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'b00;
localparam [1:0] COMPUTE = 2'b01;

// Internal registers
reg [MAX_LEN-1:0] s;
reg [5:0] len;
reg [31:0] sm;
reg [1:0] state;

// Combinational signals
reg [31:0] sum_f_new_reg;

// Combinational block to compute sum_f_new_reg
always @(*) begin
    integer i, j;
    reg [31:0] f_comb [0:MAX_LEN];
    reg [31:0] sum4;
    reg [MAX_LEN-1:0] rev_s;
    reg [5:0] z [0:MAX_LEN];
    integer l, r;
    reg [5:0] max_z;
    reg [5:0] new;
    reg [31:0] sum_f_new_temp;
    reg bad;
    reg [5:0] k;
    reg [5:0] jj;
    reg [5:0] ii;
    reg [5:0] i_val;
    reg [5:0] j_val;
    reg [5:0] i_idx;
    reg [5:0] z_val;
    reg [5:0] z_idx;
    reg [5:0] i_loop;
    reg [5:0] j_loop;
    reg [5:0] i_dp;
    reg [5:0] j_dp;
    reg [5:0] i_rev;
    reg [5:0] i_z;
    reg [5:0] i_sum;
    
    // Initialize f_comb
    for (i = 0; i <= MAX_LEN; i = i + 1) begin
        f_comb[i] = 0;
    end
    sum_f_new_temp = 0;
    
    if (len > 0) begin
        // DP
        f_comb[len] = 1;
        sum4 = 1;
        for (j_loop = 0; j_loop < len; j_loop = j_loop + 1) begin
            j_val = len - 1 - j_loop;
            bad = 0;
            if (j_val + 4 <= len) begin
                if ((s[j_val] == 0 && s[j_val+1] == 0 && s[j_val+2] == 1 && s[j_val+3] == 1) ||
                    (s[j_val] == 0 && s[j_val+1] == 1 && s[j_val+2] == 0 && s[j_val+3] == 1) ||
                    (s[j_val] == 1 && s[j_val+1] == 1 && s[j_val+2] == 1 && s[j_val+3] == 0) ||
                    (s[j_val] == 1 && s[j_val+1] == 1 && s[j_val+2] == 1 && s[j_val+3] == 1)) 
                    bad = 1;
            end
            if (bad) begin
                f_comb[j_val] = sum4 - f_comb[j_val+4];
            end else begin
                f_comb[j_val] = sum4;
            end
            sum4 = sum4 + f_comb[j_val];
        end
        
        // Reverse string
        for (i_loop = 0; i_loop < len; i_loop = i_loop + 1) begin
            i_val = i_loop;
            rev_s[i_val] = s[len-1-i_val];
        end
        
        // Z-function
        l = 0;
        r = 0;
        for (i_z = 1; i_z < len; i_z = i_z + 1) begin
            i_idx = i_z;
            if (i_idx <= r) begin
                if (r - i_idx + 1 < z[i_idx - l]) begin
                    z[i_idx] = r - i_idx + 1;
                end else begin
                    z[i_idx] = z[i_idx - l];
                end
            end else begin
                z[i_idx] = 0;
            end
            while (i_idx + z[i_idx] < len && rev_s[z[i_idx]] == rev_s[i_idx + z[i_idx]]) begin
                z[i_idx] = z[i_idx] + 1;
            end
            if (i_idx + z[i_idx] - 1 > r) begin
                l = i_idx;
                r = i_idx + z[i_idx] - 1;
            end
        end
        
        // Max z
        max_z = 0;
        for (i_loop = 1; i_loop < len; i_loop = i_loop + 1) begin
            if (z[i_loop] > max_z) max_z = z[i_loop];
        end
        
        new = len - max_z;
        
        // Sum f[0:new-1]
        sum_f_new_temp = 0;
        for (i_sum = 0; i_sum < new; i_sum = i_sum + 1) begin
            sum_f_new_temp = (sum_f_new_temp + f_comb[i_sum]) % MOD;
        end
    end
    sum_f_new_reg = sum_f_new_temp;
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        len <= 0;
        s <= 0;
        sm <= 0;
        done <= 0;
        state <= IDLE;
        answer <= 0;
    end else begin
        done <= 0;
        case (state)
            IDLE: begin
                if (start && len < MAX_LEN) begin
                    s[len] <= bit_in;
                    len <= len + 1;
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                sm <= (sm + sum_f_new_reg) % MOD;
                answer <= (sm + sum_f_new_reg) % MOD;
                done <= 1;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule