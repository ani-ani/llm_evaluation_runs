module NewmanConway (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [1:0] S_IDLE = 2'd0;
localparam [1:0] S_INIT = 2'd1;
localparam [1:0] S_COMP = 2'd2;
localparam [1:0] S_DONE = 2'd3;

// Registers
reg [1:0] state, next_state;
reg [3:0] n_reg;          // Stored n value
reg [3:0] i;              // Counter for computation (3 to n)
reg [3:0] s_idx1;         // Index for S(n-1)
reg [3:0] s_idx2;         // Index for S(n - S(n-1))
reg [15:0] s_val1;        // Value S(n-1)
reg [15:0] s_val2;        // Value S(n - S(n-1))
reg [15:0] temp_result;   // Temporary computation result
reg done_pulse;           // Internal done pulse
reg [7:0] cycle_count;    // Safety counter

// Sequence storage (16 elements, 0 to 15)
reg [15:0] sequence [0:15];

// State transition logic
always @(*) begin
    case (state)
        S_IDLE: begin
            if (start && (n_in >= 4'd1) && (n_in <= 4'd15)) begin
                if (n_in == 4'd1 || n_in == 4'd2)
                    next_state = S_DONE;
                else
                    next_state = S_INIT;
            end else begin
                next_state = S_IDLE;
            end
        end
        
        S_INIT: begin
            next_state = S_COMP;
        end
        
        S_COMP: begin
            if (i > n_reg) begin
                next_state = S_DONE;
            end else if (cycle_count >= 8'd200) begin
                next_state = S_DONE; // Safety timeout
            end else begin
                next_state = S_COMP;
            end
        end
        
        S_DONE: begin
            next_state = S_IDLE;
        end
        
        default: next_state = S_IDLE;
    endcase
end

// Sequential logic
integer idx;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        result <= 16'd0;
        done <= 1'b0;
        n_reg <= 4'd0;
        i <= 4'd0;
        s_idx1 <= 4'd0;
        s_idx2 <= 4'd0;
        s_val1 <= 16'd0;
        s_val2 <= 16'd0;
        temp_result <= 16'd0;
        done_pulse <= 1'b0;
        cycle_count <= 8'd0;
        for (idx = 0; idx < 16; idx = idx + 1) begin
            sequence[idx] <= 16'd0;
        end
    end else begin
        state <= next_state;
        done <= 1'b0;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                done_pulse <= 1'b0;
                cycle_count <= 8'd0;
                if (start && (n_in >= 4'd1) && (n_in <= 4'd15)) begin
                    n_reg <= n_in;
                    if (n_in == 4'd1 || n_in == 4'd2) begin
                        result <= 16'd1;
                    end
                end
            end
            
            S_INIT: begin
                sequence[1] <= 16'd1;
                sequence[2] <= 16'd1;
                i <= 4'd3;
                cycle_count <= 8'd0;
            end
            
            S_COMP: begin
                if (i <= n_reg) begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate S(i-1)
                    s_idx1 <= i - 4'd1;
                    s_val1 <= sequence[i - 4'd1];
                    
                    // Calculate S(i - S(i-1))
                    // S(i-1) is available from previous iteration
                    s_idx2 <= i - sequence[i - 4'd1];
                    s_val2 <= sequence[i - sequence[i - 4'd1]];
                    
                    // Compute S(i) = S(i-1) + S(i - S(i-1))
                    temp_result <= sequence[i - 4'd1] + sequence[i - sequence[i - 4'd1]];
                    
                    // Store and increment
                    sequence[i] <= sequence[i - 4'd1] + sequence[i - sequence[i - 4'd1]];
                    i <= i + 4'd1;
                end
            end
            
            S_DONE: begin
                result <= sequence[n_reg];
                done <= 1'b1;
                done_pulse <= 1'b1;
            end
            
            default: begin
                state <= S_IDLE;
                result <= 16'd0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule