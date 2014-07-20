def read_problem(io)
  problem = ''
  loop {
    ch = io.getc
    break if !ch || ch == '?'
    problem << ch
  }
  io.getc
  problem
end

answers = []

def playback(answers, io)
  answers.each do |ans|
    read_problem(io)
    io.puts ans
    io.flush
  end
end

n = 1
pnum = 1
loop do
  open('|./amida_mod', 'a+') do |io|
    playback(answers, io)

    loop do
      problem = read_problem(io)
      IO.write("amida2_problem_#{pnum}", problem)

      io.puts n
      io.flush
      result = io.gets
      if result.include?('Wrong')
        n += 1
        break
      elsif !result.include?('No.')
        puts ">>> #{result}"
      end
      answers << n
      n = 1
      puts
      warn "solved: #{pnum}"
      pnum += 1
    end
  end
end
