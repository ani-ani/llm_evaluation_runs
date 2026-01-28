module RemaindersGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [19:0] k,
    input wire c_valid,
    input wire [19:0] c_in,
    output reg result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] LOAD  = 2'd1;
    localparam [1:0] CALC  = 2'd2;
    localparam [1:0] DONE  = 2'd3;
    
    reg [1:0] state;
    reg [3:0] counter;
    reg [19:0] lcm_acc;
    reg [19:0] current_gcd;
    reg [19:0] temp_a, temp_b;
    reg [39:0] mult_temp;

    // GCD calculation using Euclidean algorithm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            lcm_acc <= 20'd1;
            current_gcd <= 20'd0;
            temp_a <= 20'd0;
            temp_b <= 20'd0;
            result <= 1'b0;
            done <= 1'b0;
            ready <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        counter <= 4'd0;
                        lcm_acc <= 20'd1;
                        ready <= 1'b1;
                    end
                end
                
                LOAD: begin
                    ready <= 1'b1;
                    if (c_valid) begin
                        // Compute gcd(k, c_in)
                        temp_a <= k;
                        temp_b <= c_in;
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    ready <= 1'b0;
                    if (temp_b == 20'd0) begin
                        current_gcd <= temp_a;
                        
                        // Compute LCM: (lcm_acc * current_gcd) / gcd(lcm_acc, current_gcd)
                        temp_a <= lcm_acc;
                        temp_b <= current_gcd;
                        state <= CALC;
                    end else if (temp_a > temp_b) begin
                        temp_a <= temp_a - temp_b;
                        state <= CALC;
                    end else begin
                        temp_b <= temp_b - temp_a;
                        state <= CALC;
                    end
                end
                
                DONE: begin
                    ready <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // LCM calculation and counter management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in main FSM
        end else begin
            if (state == CALC && temp_b == 20'd0) begin
                // GCD computation complete, now compute LCM
                if (current_gcd != 20'd0) begin
                    // Compute gcd(lcm_acc, current_gcd)
                    temp_a <= lcm_acc;
                    temp_b <= current_gcd;
                    state <= CALC;
                end else begin
                    // GCD is 0, skip LCM update
                    counter <= counter + 4'd1;
                    if (counter == n) begin
                        result <= (lcm_acc == k);
                        state <= DONE;
                    end else begin
                        state <= LOAD;
                    end
                end
            end else if (state == CALC && temp_a == 20'd0) begin
                // LCM computation complete
                mult_temp <= {20'd0, lcm_acc} * {20'd0, current_gcd};
                lcm_acc <= mult_temp[39:20] / temp_b;
                
                counter <= counter + 4'd1;
                if (counter == n) begin
                    result <= (lcm_acc == k);
                    state <= DONE;
                end else begin
                    state <= LOAD;
                end
            end
        end
    end

endmodule