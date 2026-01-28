module prefix_computer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_in [0:7],
    input wire [3:0] char_count,
    output reg [7:0] prefixes [0:7],
    output reg [3:0] valid_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] pos_counter, next_pos_counter;
    reg [3:0] valid_count_reg, next_valid_count;
    reg [7:0] prefixes_reg [0:7], next_prefixes [0:7];
    reg done_reg, next_done;
    
    // State register and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_counter <= 4'd0;
            valid_count_reg <= 4'd0;
            done_reg <= 1'b0;
            // Initialize all prefix registers
            prefixes_reg[0] <= 8'd0;
            prefixes_reg[1] <= 8'd0;
            prefixes_reg[2] <= 8'd0;
            prefixes_reg[3] <= 8'd0;
            prefixes_reg[4] <= 8'd0;
            prefixes_reg[5] <= 8'd0;
            prefixes_reg[6] <= 8'd0;
            prefixes_reg[7] <= 8'd0;
        end else begin
            state <= next_state;
            pos_counter <= next_pos_counter;
            valid_count_reg <= next_valid_count;
            done_reg <= next_done;
            prefixes_reg[0] <= next_prefixes[0];
            prefixes_reg[1] <= next_prefixes[1];
            prefixes_reg[2] <= next_prefixes[2];
            prefixes_reg[3] <= next_prefixes[3];
            prefixes_reg[4] <= next_prefixes[4];
            prefixes_reg[5] <= next_prefixes[5];
            prefixes_reg[6] <= next_prefixes[6];
            prefixes_reg[7] <= next_prefixes[7];
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_pos_counter = pos_counter;
        next_valid_count = valid_count_reg;
        next_done = done_reg;
        // Initialize next_prefixes with current values
        next_prefixes[0] = prefixes_reg[0];
        next_prefixes[1] = prefixes_reg[1];
        next_prefixes[2] = prefixes_reg[2];
        next_prefixes[3] = prefixes_reg[3];
        next_prefixes[4] = prefixes_reg[4];
        next_prefixes[5] = prefixes_reg[5];
        next_prefixes[6] = prefixes_reg[6];
        next_prefixes[7] = prefixes_reg[7];
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_pos_counter = 4'd0;
                if (start) begin
                    next_state = COMPUTE;
                    // Initialize all prefixes to 0
                    next_prefixes[0] = 8'd0;
                    next_prefixes[1] = 8'd0;
                    next_prefixes[2] = 8'd0;
                    next_prefixes[3] = 8'd0;
                    next_prefixes[4] = 8'd0;
                    next_prefixes[5] = 8'd0;
                    next_prefixes[6] = 8'd0;
                    next_prefixes[7] = 8'd0;
                    next_valid_count = char_count;
                    if (char_count == 4'd0) begin
                        next_state = DONE;
                    end
                end
            end
            
            COMPUTE: begin
                // Generate prefix length for current position
                if (pos_counter < char_count) begin
                    next_prefixes[pos_counter] = pos_counter + 8'd1;
                    next_pos_counter = pos_counter + 4'd1;
                    next_state = COMPUTE;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_done = 1'b0;
                next_pos_counter = 4'd0;
                next_valid_count = 4'd0;
            end
        endcase
    end
    
    // Output assignments
    always @(*) begin
        prefixes[0] = prefixes_reg[0];
        prefixes[1] = prefixes_reg[1];
        prefixes[2] = prefixes_reg[2];
        prefixes[3] = prefixes_reg[3];
        prefixes[4] = prefixes_reg[4];
        prefixes[5] = prefixes_reg[5];
        prefixes[6] = prefixes_reg[6];
        prefixes[7] = prefixes_reg[7];
        valid_count = valid_count_reg;
        done = done_reg;
    end

endmodule