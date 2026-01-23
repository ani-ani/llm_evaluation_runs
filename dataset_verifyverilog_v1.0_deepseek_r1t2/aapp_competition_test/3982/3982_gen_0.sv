module morse_counter #(
    parameter MAX_LEN = 32,
    parameter MOD = 32'd1000000007
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire bit_in,
    output reg [31:0] answer,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    
    // Internal registers
    reg [1:0] state;
    reg [31:0] sm;
    reg [5:0] len;
    reg [31:0] s;
    
    // Combinational logic signals
    reg [31:0] sum_f_new;
    
    // Combinational calculations
    always @(*) begin
        integer i, j;
        reg [31:0] f [0:MAX_LEN];
        reg [31:0] sm_temp;
        reg [5:0] z [0:MAX_LEN];
        reg [5:0] max_z;
        reg bad;
        integer l, r;
        
        // Initialize f array
        for (i = 0; i <= MAX_LEN; i = i + 1) begin
            f[i] = 32'd0;
        end
        
        sm_temp = 32'd0;
        
        if (len > 6'd0) begin
            // Dynamic programming calculation
            f[len] = 32'd1;
            sm_temp = 32'd1;
            
            for (j = len - 1; j >= 0; j = j - 1) begin
                bad = 1'b0;
                if (j + 4 <= len) begin
                    if ((s[j] == 1'b0 && s[j+1] == 1'b0 && s[j+2] == 1'b1 && s[j+3] == 1'b1) ||
                        (s[j] == 1'b0 && s[j+1] == 1'b1 && s[j+2] == 1'b0 && s[j+3] == 1'b1) ||
                        (s[j] == 1'b1 && s[j+1] == 1'b1 && s[j+2] == 1'b1 && s[j+3] == 1'b0) ||
                        (s[j] == 1'b1 && s[j+1] == 1'b1 && s[j+2] == 1'b1 && s[j+3] == 1'b1)) begin
                        bad = 1'b1;
                    end
                end
                
                if (bad) begin
                    f[j] = (sm_temp - f[j+4]) % MOD;
                end else begin
                    f[j] = sm_temp % MOD;
                end
                
                sm_temp = (sm_temp + f[j]) % MOD;
            end
            
            // Reverse string calculation
            reg [MAX_LEN-1:0] rev_s;
            for (i = 0; i < len; i = i + 1) begin
                rev_s[i] = s[len - 1 - i];
            end
            
            // Z-algorithm
            for (i = 1; i < len; i = i + 1) begin
                if (i <= r) begin
                    if (r - i + 1 < z[i - l]) begin
                        z[i] = r - i + 1;
                    end else begin
                        z[i] = z[i - l];
                    end
                end else begin
                    z[i] = 6'd0;
                end
                
                while (i + z[i] < len && rev_s[z[i]] == rev_s[i + z[i]]) begin
                    z[i] = z[i] + 6'd1;
                end
                
                if (i + z[i] - 1 > r) begin
                    l = i;
                    r = i + z[i] - 1;
                end
            end
            
            max_z = 6'd0;
            for (i = 1; i < len; i = i + 1) begin
                if (z[i] > max_z) begin
                    max_z = z[i];
                end
            end
            
            sum_f_new = 32'd0;
            if (len - max_z > 0) begin
                for (i = 0; i < len - max_z; i = i + 1) begin
                    sum_f_new = (sum_f_new + f[i]) % MOD;
                end
            end
        end else begin
            sum_f_new = 32'd0;
        end
    end
    
    // FSM and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sm <= 32'd0;
            len <= 6'd0;
            s <= 32'd0;
            done <= 1'b0;
            answer <= 32'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        s[len] <= bit_in;
                        len <= len + 6'd1;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    sm <= (sm + sum_f_new) % MOD;
                    answer <= (sm + sum_f_new) % MOD;
                    done <= 1'b1;
                    
                    if (len >= MAX_LEN) begin
                        // Reset if reached max length
                        len <= 6'd0;
                        s <= 32'd0;
                    end
                    
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule