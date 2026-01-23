module spell_power_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input valid_input,
    output reg [7:0] power,
    output reg done
);

    // Memory to store 16 characters
    reg [7:0] str_mem [0:15];
    reg [3:0] mem_wr_ptr;
    
    // FSM States
    localparam IDLE = 3'b000;
    localparam COLLECTING = 3'b001;
    localparam CHECKING = 3'b010;
    localparam DONE = 3'b011;
    
    reg [2:0] state;
    
    // Checking variables
    reg [3:0] start_pos;       // Start index of substring
    reg [3:0] sub_len;         // Length of substring (4*L)
    reg [2:0] w_len;           // L (1, 2, 3, 4)
    reg [3:0] idx;             // Index for comparisons
    reg match;                 // Flag for current substring match
    reg [7:0] next_power;      // Computed power for current substring
    
    // Store characters when valid_input is high
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wr_ptr <= 4'd0;
        end else if (valid_input && state == COLLECTING) begin
            str_mem[char_index] <= char_in;
            mem_wr_ptr <= mem_wr_ptr + 1'b1;
        end else if (state == IDLE && start) begin
            mem_wr_ptr <= 4'd0;
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            power <= 8'd0;
            done <= 1'b0;
            start_pos <= 4'd0;
            sub_len <= 4'd0;
            w_len <= 3'd0;
            match <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    power <= 8'd0;
                    if (start) begin
                        state <= COLLECTING;
                    end
                end
                
                COLLECTING: begin
                    if (mem_wr_ptr == 4'd15 && valid_input) begin
                        // All characters collected, wait a cycle to ensure storage
                        state <= CHECKING;
                        start_pos <= 4'd0;
                        w_len <= 3'd1; // Start with L=1
                        sub_len <= 4'd4;
                        idx <= 4'd0;
                        match <= 1'b1;
                    end
                end
                
                CHECKING: begin
                    // Check current substring configuration
                    // Pattern: w, w^R, w, w^R
                    // w length = w_len (1 to 4)
                    // Total length = 4 * w_len = sub_len
                    
                    // Check if current position/length/idx combination matches
                    // Determine which part we are comparing
                    // Part 0: w[0] vs w[2*w_len + idx] (first w vs second w)
                    // Part 1: w[idx] vs w[2*w_len - 1 - idx] (w vs w^R)
                    // Actually, need to check specific bits carefully
                    
                    if (match) begin
                        // Check current comparison
                        // Pattern: Start -> Start+w_len -> Start+2*w_len -> Start+3*w_len
                        // w = str[Start : Start+w_len-1]
                        // w^R = str[Start+w_len : Start+2*w_len-1] (reversed)
                        // w = str[Start+2*w_len : Start+3*w_len-1]
                        // w^R = str[Start+3*w_len : Start+4*w_len-1] (reversed)
                        
                        // We iterate idx from 0 to w_len-1
                        // Check 1: str[Start + idx] == str[Start + 2*w_len + idx]  (w == w)
                        // Check 2: str[Start + idx] == str[Start + 3*w_len - 1 - idx] (w == w^R)
                        // Check 3: str[Start + w_len + idx] == str[Start + 3*w_len + (w_len-1-idx)] (w^R == w^R) - implicit if above hold
                        
                        // Optimization: 
                        // Check 1: (first w) == (second w)
                        // Check 2: (first w) == (second w^R)
                        
                        if (str_mem[start_pos + idx] != str_mem[start_pos + 2*w_len + idx]) begin
                            match <= 1'b0; // Check 1 failed
                        end else if (str_mem[start_pos + idx] != str_mem[start_pos + 3*w_len - 1 - idx]) begin
                            match <= 1'b0; // Check 2 failed
                        end else begin
                            // This comparison passed, increment idx
                            if (idx < w_len - 1) begin
                                idx <= idx + 1'b1;
                            end else begin
                                // Finished checking this substring (matched!)
                                // Update power if this length is greater
                                if (sub_len > power) begin
                                    power <= {4'd0, sub_len}; // sub_len is 4, 8, 12, 16
                                end
                                
                                // Move to next configuration
                                // Priority: Increase w_len (up to 4), then increase start_pos
                                if (w_len < 3'd4) begin
                                    w_len <= w_len + 1'b1;
                                    sub_len <= sub_len + 4'd4; // +4 length
                                    idx <= 4'd0;
                                    match <= 1'b1;
                                end else begin
                                    // Reset w_len, increment start_pos
                                    if (start_pos < 4'd15) begin
                                        w_len <= 3'd1;
                                        sub_len <= 4'd4;
                                        start_pos <= start_pos + 1'b1;
                                        idx <= 4'd0;
                                        match <= 1'b1;
                                    end else begin
                                        // All configurations checked
                                        state <= DONE;
                                    end
                                end
                            end
                        end
                    end else begin
                        // Match failed for current idx/w_len/start_pos
                        // Move to next configuration
                        if (w_len < 3'd4) begin
                            w_len <= w_len + 1'b1;
                            sub_len <= sub_len + 4'd4;
                            idx <= 4'd0;
                            match <= 1'b1;
                        end else begin
                            if (start_pos < 4'd15) begin
                                w_len <= 3'd1;
                                sub_len <= 4'd4;
                                start_pos <= start_pos + 1'b1;
                                idx <= 4'd0;
                                match <= 1'b1;
                            end else begin
                                state <= DONE;
                            end
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
