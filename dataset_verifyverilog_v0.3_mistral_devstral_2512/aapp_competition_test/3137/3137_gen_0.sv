module bacteria_sim(
    input clk,
    input rst_n,
    input start,
    input [7:0] trap_row,
    input [7:0] trap_col,
    input [7:0] start_row_0,
    input [7:0] start_col_0,
    input [1:0] start_dir_0,
    input [7:0] start_row_1,
    input [7:0] start_col_1,
    input [1:0] start_dir_1,
    input [3:0] grid_0 [0:7][0:7],
    input [3:0] grid_1 [0:7][0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SIMULATE = 3'd2;
    localparam [2:0] FINISH  = 3'd3;
    
    reg [2:0] state;
    reg [7:0] time_step;
    
    // Bacteria 0 state
    reg [7:0] row_0;
    reg [7:0] col_0;
    reg [1:0] dir_0;
    
    // Bacteria 1 state
    reg [7:0] row_1;
    reg [7:0] col_1;
    reg [1:0] dir_1;
    
    // Direction constants
    localparam [1:0] UP    = 2'd0;
    localparam [1:0] RIGHT = 2'd1;
    localparam [1:0] DOWN  = 2'd2;
    localparam [1:0] LEFT  = 2'd3;
    
    // Maximum simulation steps
    localparam [7:0] MAX_STEPS = 8'd255;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            time_step <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            
            row_0 <= 8'd0;
            col_0 <= 8'd0;
            dir_0 <= 2'd0;
            
            row_1 <= 8'd0;
            col_1 <= 8'd0;
            dir_1 <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize bacteria positions
                    row_0 <= start_row_0;
                    col_0 <= start_col_0;
                    dir_0 <= start_dir_0;
                    
                    row_1 <= start_row_1;
                    col_1 <= start_col_1;
                    dir_1 <= start_dir_1;
                    
                    time_step <= 8'd0;
                    state <= SIMULATE;
                end
                
                SIMULATE: begin
                    // Check if both bacteria are at trap
                    if ((row_0 == trap_row && col_0 == trap_col) && 
                        (row_1 == trap_row && col_1 == trap_col)) begin
                        result <= time_step;
                        state <= FINISH;
                    end else if (time_step == MAX_STEPS) begin
                        result <= 16'd65535;
                        state <= FINISH;
                    end else begin
                        // Move bacteria 0
                        reg [1:0] new_dir_0;
                        reg [7:0] new_row_0;
                        reg [7:0] new_col_0;
                        
                        // Read grid value and turn clockwise
                        new_dir_0 = dir_0;
                        integer i;
                        for (i = 0; i < grid_0[row_0-1][col_0-1]; i = i + 1) begin
                            new_dir_0 = new_dir_0 + 2'd1;
                            if (new_dir_0 == 2'd4) begin
                                new_dir_0 = 2'd0;
                            end
                        end
                        
                        // Move in new direction
                        case (new_dir_0)
                            UP: begin
                                new_row_0 = row_0 - 8'd1;
                                new_col_0 = col_0;
                                if (new_row_0 == 8'd0) begin
                                    new_row_0 = 8'd8;
                                end
                            end
                            RIGHT: begin
                                new_row_0 = row_0;
                                new_col_0 = col_0 + 8'd1;
                                if (new_col_0 == 8'd9) begin
                                    new_col_0 = 8'd1;
                                end
                            end
                            DOWN: begin
                                new_row_0 = row_0 + 8'd1;
                                new_col_0 = col_0;
                                if (new_row_0 == 8'd9) begin
                                    new_row_0 = 8'd1;
                                end
                            end
                            LEFT: begin
                                new_row_0 = row_0;
                                new_col_0 = col_0 - 8'd1;
                                if (new_col_0 == 8'd0) begin
                                    new_col_0 = 8'd8;
                                end
                            end
                            default: begin
                                new_row_0 = row_0;
                                new_col_0 = col_0;
                            end
                        endcase
                        
                        row_0 <= new_row_0;
                        col_0 <= new_col_0;
                        dir_0 <= new_dir_0;
                        
                        // Move bacteria 1
                        reg [1:0] new_dir_1;
                        reg [7:0] new_row_1;
                        reg [7:0] new_col_1;
                        
                        // Read grid value and turn clockwise
                        new_dir_1 = dir_1;
                        for (i = 0; i < grid_1[row_1-1][col_1-1]; i = i + 1) begin
                            new_dir_1 = new_dir_1 + 2'd1;
                            if (new_dir_1 == 2'd4) begin
                                new_dir_1 = 2'd0;
                            end
                        end
                        
                        // Move in new direction
                        case (new_dir_1)
                            UP: begin
                                new_row_1 = row_1 - 8'd1;
                                new_col_1 = col_1;
                                if (new_row_1 == 8'd0) begin
                                    new_row_1 = 8'd8;
                                end
                            end
                            RIGHT: begin
                                new_row_1 = row_1;
                                new_col_1 = col_1 + 8'd1;
                                if (new_col_1 == 8'd9) begin
                                    new_col_1 = 8'd1;
                                end
                            end
                            DOWN: begin
                                new_row_1 = row_1 + 8'd1;
                                new_col_1 = col_1;
                                if (new_row_1 == 8'd9) begin
                                    new_row_1 = 8'd1;
                                end
                            end
                            LEFT: begin
                                new_row_1 = row_1;
                                new_col_1 = col_1 - 8'd1;
                                if (new_col_1 == 8'd0) begin
                                    new_col_1 = 8'd8;
                                end
                            end
                            default: begin
                                new_row_1 = row_1;
                                new_col_1 = col_1;
                            end
                        endcase
                        
                        row_1 <= new_row_1;
                        col_1 <= new_col_1;
                        dir_1 <= new_dir_1;
                        
                        time_step <= time_step + 8'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule